import A2ACore
import Foundation

/// `AgentExecutor` を子タスクで起動し、`EventQueue` の `StreamResponse` を `TaskManager` /
/// `ResultAggregator` で集約・永続化する `RequestHandler` 既定実装（a2a-python `DefaultRequestHandler`）。
public actor DefaultRequestHandler: RequestHandler {
    private let agentCard: AgentCard
    private let executor: any AgentExecutor
    private let taskStore: any TaskStore
    private let queueManager: any QueueManager
    private let pushConfigStore: (any PushNotificationConfigStore)?
    private let pushSender: (any PushNotificationSender)?

    /// 実行中の producer（`execute`）Task を taskId 別に追跡し、`onCancelTask` で中断できるようにする。
    private var runningProducers: [TaskID: Task<Void, Never>] = [:]

    public init(
        agentCard: AgentCard,
        executor: any AgentExecutor,
        taskStore: any TaskStore = InMemoryTaskStore(),
        queueManager: any QueueManager = InMemoryQueueManager(),
        pushConfigStore: (any PushNotificationConfigStore)? = nil,
        pushSender: (any PushNotificationSender)? = nil
    ) {
        self.agentCard = agentCard
        self.executor = executor
        self.taskStore = taskStore
        self.queueManager = queueManager
        self.pushConfigStore = pushConfigStore
        self.pushSender = pushSender
    }

    // MARK: - message/send

    public func onMessageSend(_ params: SendMessageRequest, context: ServerCallContext) async throws -> SendMessageResponse {
        let requestContext = try await buildContext(params, context)
        await registerInlinePushConfig(params, taskId: requestContext.taskId, context: context)
        let queue = await queueManager.createOrGet(requestContext.taskId)
        let taskManager = TaskManager(
            taskId: requestContext.taskId,
            contextId: requestContext.contextId,
            store: taskStore,
            initialTask: requestContext.currentTask,
            callContext: context
        )
        let blocking = !(params.configuration?.returnImmediately ?? false)

        let result: SendMessageResponse
        if blocking {
            guard let driven = try await drive(requestContext, queue: queue, taskManager: taskManager) else {
                throw A2AServerError.internalError("No result produced")
            }
            result = driven
        } else {
            // spec §448: タスクを作成したら即座に返す（実行は背景で継続）。イベント待ちはしない。
            // 既存タスクが無ければ submitted のタスクを生成・永続化し、getTask が即引けるようにする。
            let initialTask = requestContext.currentTask
                ?? A2ATask(id: requestContext.taskId, contextId: requestContext.contextId, status: TaskStatus(state: .submitted, timestamp: Date()))
            try await taskStore.save(initialTask, context: context)
            Task { [weak self] in _ = try? await self?.drive(requestContext, queue: queue, taskManager: taskManager) }
            result = .task(initialTask)
        }

        return applyHistoryLength(result, configuration: params.configuration)
    }

    // MARK: - message/stream

    public func onMessageSendStream(_ params: SendMessageRequest, context: ServerCallContext) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        guard agentCard.capabilities.streaming == true else {
            throw A2AServerError.unsupportedOperation("Streaming is not supported by the agent")
        }
        let requestContext = try await buildContext(params, context)
        await registerInlinePushConfig(params, taskId: requestContext.taskId, context: context)
        let queue = await queueManager.createOrGet(requestContext.taskId)
        let taskManager = TaskManager(
            taskId: requestContext.taskId,
            contextId: requestContext.contextId,
            store: taskStore,
            initialTask: requestContext.currentTask,
            callContext: context
        )
        let stream = await queue.tap()
        let executor = self.executor

        return AsyncThrowingStream { continuation in
            let producer = Task { await Self.runExecutor(executor, requestContext, queue) }
            let consumer = Task { [weak self] in
                await self?.registerProducer(producer, for: requestContext.taskId)
                for await event in stream {
                    _ = try? await taskManager.process(event)
                    await self?.sendPushIfNeeded(requestContext.taskId, event)
                    continuation.yield(event)
                }
                _ = await producer.value
                await self?.removeProducer(for: requestContext.taskId)
                await self?.queueManager.close(requestContext.taskId)
                continuation.finish()
            }
            continuation.onTermination = { _ in
                producer.cancel()
                consumer.cancel()
            }
        }
    }

    // MARK: - tasks/get, list, cancel

    public func onGetTask(_ params: GetTaskRequest, context: ServerCallContext) async throws -> A2ATask? {
        guard var task = try await taskStore.get(params.id, context: context) else { return nil }
        if let length = params.historyLength {
            task.history = Array(task.history.suffix(max(0, length)))
        }
        return task
    }

    public func onListTasks(_ params: ListTasksRequest, context: ServerCallContext) async throws -> ListTasksResponse {
        try await taskStore.list(params, context: context)
    }

    public func onCancelTask(_ params: CancelTaskRequest, context: ServerCallContext) async throws -> A2ATask? {
        // a2a-python on_cancel_task: 未知タスクは TaskNotFound、終端は TaskNotCancelable。
        guard let task = try await taskStore.get(params.id, context: context) else {
            throw A2AServerError.taskNotFound(params.id)
        }
        if task.status.state.isTerminal {
            throw A2AServerError.taskNotCancelable(params.id)
        }
        // 実行中の producer があれば中断し、そのストリームを閉じる。
        runningProducers[task.id]?.cancel()
        runningProducers[task.id] = nil
        await queueManager.close(task.id)

        // executor.cancel を専用キューで実行し、その出力イベントから結果を集約する
        // （a2a-python: キャンセルは executor 主導。最終状態が CANCELED でなければ不可）。
        let cancelContext = RequestContext(
            message: nil,
            taskId: task.id,
            contextId: task.contextId ?? ContextID(UUID().uuidString),
            currentTask: task,
            callContext: context
        )
        let taskManager = TaskManager(
            taskId: task.id,
            contextId: cancelContext.contextId,
            store: taskStore,
            initialTask: task,
            callContext: context
        )
        let queue = EventQueue()
        let stream = await queue.tap()
        let executor = self.executor
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await Self.runCancel(executor, cancelContext, queue) }
            for await event in stream { _ = try? await taskManager.process(event) }
        }

        let result = await taskManager.getTask() ?? task
        if result.status.state != .canceled {
            throw A2AServerError.taskNotCancelable(params.id)
        }
        return result
    }

    // MARK: - tasks:subscribe

    public func onSubscribeToTask(_ params: SubscribeToTaskRequest, context: ServerCallContext) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        // a2a-python on_subscribe_to_task と同順: get → terminal → yield task → tap queue。
        guard let task = try await taskStore.get(params.id, context: context) else {
            throw A2AServerError.taskNotFound(params.id)
        }
        if task.status.state.isTerminal {
            throw A2AServerError.unsupportedOperation("Task \(params.id) is in terminal state: \(task.status.state)")
        }
        let queue = await queueManager.get(params.id)
        let stream = await queue?.tap()
        return AsyncThrowingStream { continuation in
            // spec §311: 最初のイベントは必ず現在の Task。
            continuation.yield(.task(task))
            guard let stream else {
                continuation.finish(throwing: A2AServerError.taskNotFound(params.id))
                return
            }
            let pump = Task {
                for await event in stream {
                    continuation.yield(event)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in pump.cancel() }
        }
    }

    // MARK: - push notification config

    public func onCreateTaskPushNotificationConfig(_ params: TaskPushNotificationConfig, context: ServerCallContext) async throws -> TaskPushNotificationConfig {
        guard let store = pushConfigStore else { throw A2AServerError.pushNotificationNotSupported }
        return try await store.set(params, context: context)
    }

    public func onGetTaskPushNotificationConfig(_ params: GetTaskPushNotificationConfigRequest, context: ServerCallContext) async throws -> TaskPushNotificationConfig {
        guard let store = pushConfigStore else { throw A2AServerError.pushNotificationNotSupported }
        let configs = try await store.get(taskId: params.taskId, context: context)
        guard let match = configs.first(where: { $0.id == params.id }) else {
            throw A2AServerError.invalidParams("Push notification config not found: \(params.id)")
        }
        return match
    }

    public func onListTaskPushNotificationConfigs(_ params: ListTaskPushNotificationConfigsRequest, context: ServerCallContext) async throws -> ListTaskPushNotificationConfigsResponse {
        guard let store = pushConfigStore else { throw A2AServerError.pushNotificationNotSupported }
        let configs = try await store.get(taskId: params.taskId, context: context)
        return ListTaskPushNotificationConfigsResponse(configs: configs)
    }

    public func onDeleteTaskPushNotificationConfig(_ params: DeleteTaskPushNotificationConfigRequest, context: ServerCallContext) async throws {
        guard let store = pushConfigStore else { throw A2AServerError.pushNotificationNotSupported }
        try await store.delete(taskId: params.taskId, configId: params.id, context: context)
    }

    // MARK: - extended agent card

    public func onGetExtendedAgentCard(_ params: GetExtendedAgentCardRequest, context: ServerCallContext) async throws -> AgentCard {
        guard agentCard.capabilities.extendedAgentCard == true else {
            throw A2AServerError.extendedAgentCardNotConfigured
        }
        return agentCard
    }

    // MARK: - Private

    private func registerProducer(_ task: Task<Void, Never>, for id: TaskID) {
        runningProducers[id] = task
    }

    private func removeProducer(for id: TaskID) {
        runningProducers[id] = nil
    }

    private func buildContext(_ params: SendMessageRequest, _ context: ServerCallContext) async throws -> RequestContext {
        let message = params.message
        var current: A2ATask?
        if let taskId = message.taskId {
            current = try await taskStore.get(taskId, context: context)
        }
        let taskId = message.taskId ?? current?.id ?? TaskID(UUID().uuidString)
        let contextId = message.contextId ?? current?.contextId ?? ContextID(UUID().uuidString)
        return RequestContext(
            message: message,
            taskId: taskId,
            contextId: contextId,
            currentTask: current,
            callContext: context
        )
    }

    /// 権威ある集約: producer を起動し、終端/中断までイベントを消費・永続化・push する。
    @discardableResult
    private func drive(_ requestContext: RequestContext, queue: EventQueue, taskManager: TaskManager) async throws -> SendMessageResponse? {
        let stream = await queue.tap()
        let executor = self.executor
        var result: SendMessageResponse?
        // 構造化: producer を子タスクとして起動する。drive（= onMessageSend）を await する
        // 親（オーケストレータ）がキャンセルされると、この group ごと子の executor まで伝播する。
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { await Self.runExecutor(executor, requestContext, queue) }
            for await event in stream {
                try await taskManager.process(event)
                await sendPushIfNeeded(requestContext.taskId, event)
                if case .message(let message) = event {
                    result = .message(message)
                } else if event.isFinal || event.isInterrupt {
                    if let task = await taskManager.getTask() { result = .task(task) }
                }
            }
        }
        await queueManager.close(requestContext.taskId)
        if result == nil, let task = await taskManager.getTask() {
            result = .task(task)
        }
        return result
    }

    /// SendMessageConfiguration 内の push 設定を store に登録する（a2a-python on_message_send 211-216）。
    private func registerInlinePushConfig(_ params: SendMessageRequest, taskId: TaskID, context: ServerCallContext) async {
        guard let store = pushConfigStore, var config = params.configuration?.taskPushNotificationConfig else { return }
        if config.taskId == nil { config.taskId = taskId }
        _ = try? await store.set(config, context: context)
    }

    private func sendPushIfNeeded(_ taskId: TaskID, _ event: StreamResponse) async {
        guard let sender = pushSender, let store = pushConfigStore else { return }
        // 配信は owner 横断（a2a-python sender は get_info_for_dispatch を使う）。
        guard let configs = try? await store.configs(forDispatch: taskId), !configs.isEmpty else { return }
        for config in configs {
            await sender.send(event, to: config)
        }
    }

    private func applyHistoryLength(_ response: SendMessageResponse, configuration: SendMessageConfiguration?) -> SendMessageResponse {
        guard case .task(var task) = response, let length = configuration?.historyLength else {
            return response
        }
        task.history = Array(task.history.suffix(max(0, length)))
        return .task(task)
    }

    private static func runExecutor(_ executor: any AgentExecutor, _ context: RequestContext, _ queue: EventQueue) async {
        do {
            try await executor.execute(context, eventQueue: queue)
        } catch is CancellationError {
            // キャンセルは正常終了として扱う。
        } catch {
            let status = TaskStatus(state: .failed, message: nil, timestamp: Date())
            await queue.enqueue(.statusUpdate(TaskStatusUpdateEvent(
                taskId: context.taskId,
                contextId: context.contextId,
                status: status
            )))
        }
        await queue.close()
    }

    private static func runCancel(_ executor: any AgentExecutor, _ context: RequestContext, _ queue: EventQueue) async {
        do {
            try await executor.cancel(context, eventQueue: queue)
        } catch {
            let status = TaskStatus(state: .canceled, message: nil, timestamp: Date())
            await queue.enqueue(.statusUpdate(TaskStatusUpdateEvent(
                taskId: context.taskId,
                contextId: context.contextId,
                status: status
            )))
        }
        await queue.close()
    }
}

import A2ACore
import Foundation

/// `RequestHandler` の既定実装（a2a-python `DefaultRequestHandler`）。
///
/// `AgentExecutor` を producer task で起動し、`EventQueue` に流れる `StreamResponse` を
/// `TaskManager` / `ResultAggregator` で集約・永続化し、必要に応じてプッシュ通知を送る。
public actor DefaultRequestHandler: RequestHandler {
    private let agentCard: AgentCard
    private let executor: any AgentExecutor
    private let taskStore: any TaskStore
    private let queueManager: any QueueManager
    private let pushConfigStore: (any PushNotificationConfigStore)?
    private let pushSender: (any PushNotificationSender)?

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
        let queue = await queueManager.createOrGet(requestContext.taskId)
        let taskManager = TaskManager(
            taskId: requestContext.taskId,
            contextId: requestContext.contextId,
            store: taskStore,
            initialTask: requestContext.currentTask
        )
        let blocking = !(params.configuration?.returnImmediately ?? false)

        let result: SendMessageResponse?
        if blocking {
            result = try await drive(requestContext, queue: queue, taskManager: taskManager)
        } else {
            // returnImmediately: 権威ある集約はバックグラウンドで継続し、
            // 最初に確定したスナップショットを返す。
            let snapshotStream = await queue.tap()
            Task { [weak self] in _ = try? await self?.drive(requestContext, queue: queue, taskManager: taskManager) }
            result = try await firstSnapshot(from: snapshotStream, taskManager: taskManager)
        }

        guard let result else { throw A2AServerError.internalError("No result produced") }
        return applyHistoryLength(result, configuration: params.configuration)
    }

    // MARK: - message/stream

    public func onMessageSendStream(_ params: SendMessageRequest, context: ServerCallContext) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        guard agentCard.capabilities.streaming == true else {
            throw A2AServerError.unsupportedOperation("Streaming is not supported by the agent")
        }
        let requestContext = try await buildContext(params, context)
        let queue = await queueManager.createOrGet(requestContext.taskId)
        let taskManager = TaskManager(
            taskId: requestContext.taskId,
            contextId: requestContext.contextId,
            store: taskStore,
            initialTask: requestContext.currentTask
        )
        let stream = await queue.tap()
        let executor = self.executor

        return AsyncThrowingStream { continuation in
            let producer = Task { await Self.runExecutor(executor, requestContext, queue) }
            Task { [weak self] in
                for await event in stream {
                    _ = try? await taskManager.process(event)
                    await self?.sendPushIfNeeded(requestContext.taskId, event)
                    continuation.yield(event)
                }
                _ = await producer.value
                await self?.queueManager.close(requestContext.taskId)
                continuation.finish()
            }
        }
    }

    // MARK: - tasks/get, list, cancel

    public func onGetTask(_ params: GetTaskRequest, context: ServerCallContext) async throws -> A2ATask? {
        guard var task = try await taskStore.get(params.id) else { return nil }
        if let length = params.historyLength {
            task.history = Array(task.history.suffix(max(0, length)))
        }
        return task
    }

    public func onListTasks(_ params: ListTasksRequest, context: ServerCallContext) async throws -> ListTasksResponse {
        try await taskStore.list(params)
    }

    public func onCancelTask(_ params: CancelTaskRequest, context: ServerCallContext) async throws -> A2ATask? {
        guard let task = try await taskStore.get(params.id) else { return nil }
        if task.status.state.isTerminal {
            throw A2AServerError.taskNotCancelable(params.id)
        }
        let requestContext = RequestContext(
            message: nil,
            taskId: task.id,
            contextId: task.contextId ?? ContextID(UUID().uuidString),
            currentTask: task,
            callContext: context
        )
        let queue = await queueManager.createOrGet(task.id)
        let taskManager = TaskManager(taskId: task.id, contextId: requestContext.contextId, store: taskStore, initialTask: task)
        let executor = self.executor
        let stream = await queue.tap()
        let producer = Task { await Self.runCancel(executor, requestContext, queue) }
        for await event in stream {
            try await taskManager.process(event)
        }
        _ = await producer.value
        await queueManager.close(task.id)
        return await taskManager.getTask()
    }

    // MARK: - tasks:subscribe

    public func onSubscribeToTask(_ params: SubscribeToTaskRequest, context: ServerCallContext) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        guard let queue = await queueManager.get(params.id) else {
            throw A2AServerError.taskNotFound(params.id)
        }
        let snapshot = try await taskStore.get(params.id)
        let stream = await queue.tap()
        return AsyncThrowingStream { continuation in
            if let snapshot {
                continuation.yield(.task(snapshot))
            }
            Task {
                for await event in stream {
                    continuation.yield(event)
                }
                continuation.finish()
            }
        }
    }

    // MARK: - push notification config

    public func onCreateTaskPushNotificationConfig(_ params: TaskPushNotificationConfig, context: ServerCallContext) async throws -> TaskPushNotificationConfig {
        guard let store = pushConfigStore else { throw A2AServerError.pushNotificationNotSupported }
        return try await store.set(params)
    }

    public func onGetTaskPushNotificationConfig(_ params: GetTaskPushNotificationConfigRequest, context: ServerCallContext) async throws -> TaskPushNotificationConfig {
        guard let store = pushConfigStore else { throw A2AServerError.pushNotificationNotSupported }
        let configs = try await store.get(taskId: params.taskId)
        guard let match = configs.first(where: { $0.id == params.id }) else {
            throw A2AServerError.invalidParams("Push notification config not found: \(params.id)")
        }
        return match
    }

    public func onListTaskPushNotificationConfigs(_ params: ListTaskPushNotificationConfigsRequest, context: ServerCallContext) async throws -> ListTaskPushNotificationConfigsResponse {
        guard let store = pushConfigStore else { throw A2AServerError.pushNotificationNotSupported }
        let configs = try await store.get(taskId: params.taskId)
        return ListTaskPushNotificationConfigsResponse(configs: configs)
    }

    public func onDeleteTaskPushNotificationConfig(_ params: DeleteTaskPushNotificationConfigRequest, context: ServerCallContext) async throws {
        guard let store = pushConfigStore else { throw A2AServerError.pushNotificationNotSupported }
        try await store.delete(taskId: params.taskId, configId: params.id)
    }

    // MARK: - extended agent card

    public func onGetExtendedAgentCard(_ params: GetExtendedAgentCardRequest, context: ServerCallContext) async throws -> AgentCard {
        guard agentCard.capabilities.extendedAgentCard == true else {
            throw A2AServerError.extendedAgentCardNotConfigured
        }
        return agentCard
    }

    // MARK: - Private

    private func buildContext(_ params: SendMessageRequest, _ context: ServerCallContext) async throws -> RequestContext {
        let message = params.message
        var current: A2ATask?
        if let taskId = message.taskId {
            current = try await taskStore.get(taskId)
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
        let producer = Task { await Self.runExecutor(executor, requestContext, queue) }
        var result: SendMessageResponse?
        for await event in stream {
            try await taskManager.process(event)
            await sendPushIfNeeded(requestContext.taskId, event)
            if case .message(let message) = event {
                result = .message(message)
            } else if event.isFinal || event.isInterrupt {
                if let task = await taskManager.getTask() { result = .task(task) }
            }
        }
        _ = await producer.value
        await queueManager.close(requestContext.taskId)
        if result == nil, let task = await taskManager.getTask() {
            result = .task(task)
        }
        return result
    }

    /// 最初に確定したスナップショット（Task / Message）を返す（returnImmediately 用）。
    private func firstSnapshot(from stream: AsyncStream<StreamResponse>, taskManager: TaskManager) async throws -> SendMessageResponse? {
        for await event in stream {
            if case .message(let message) = event {
                return .message(message)
            }
            if let task = await taskManager.getTask() {
                return .task(task)
            }
            if case .task(let task) = event {
                return .task(task)
            }
        }
        if let task = await taskManager.getTask() { return .task(task) }
        return nil
    }

    private func sendPushIfNeeded(_ taskId: TaskID, _ event: StreamResponse) async {
        guard let sender = pushSender, let store = pushConfigStore else { return }
        guard let configs = try? await store.get(taskId: taskId), !configs.isEmpty else { return }
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

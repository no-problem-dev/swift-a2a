import A2ACore
import Foundation

/// Runs the executor and turns its events into persisted task state and client responses.
///
/// This is where the framework's guarantees are implemented: an executor is started as a child
/// task, its events are folded through a ``TaskManager`` and saved, pushed to any registered
/// webhooks, and — for a blocking send — consumed until the task settles. Aggregation happens here
/// rather than in ``ResultAggregator``, which this type does not use.
///
/// Streaming and cancellation both require the executor's cooperation: a stream ends when the
/// executor publishes a terminal or interrupted state, and a cancellation succeeds only if the
/// executor's `cancel` leaves the task in the canceled state.
public actor DefaultRequestHandler: RequestHandler {
    private let agentCard: AgentCard
    private let executor: any AgentExecutor
    private let taskStore: any TaskStore
    private let queueManager: any QueueManager
    private let pushConfigStore: (any PushNotificationConfigStore)?
    private let pushSender: (any PushNotificationSender)?

    /// Running executor tasks, so a cancellation request can interrupt the one it targets. Only
    /// streaming and non-blocking runs are tracked; a blocking send's executor lives inside its
    /// task group and is cancelled with the caller instead.
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

    /// Sends a message and answers with the settled outcome.
    ///
    /// Blocks until the executor reaches a terminal or interrupted state, unless the request asks
    /// to return immediately — in which case a submitted task is saved and returned while the
    /// executor keeps running in the background, and the returned snapshot will never update.
    ///
    /// A webhook configuration carried in the request is registered before the executor starts, so
    /// it catches the run's own events.
    ///
    /// - Throws: `A2AServerError.internalError` if the executor produced no result at all.
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
            // Return as soon as the task exists. A new task is created and saved first, so a
            // client that immediately fetches or subscribes finds something there.
            let initialTask = requestContext.currentTask
                ?? A2ATask(id: requestContext.taskId, contextId: requestContext.contextId, status: TaskStatus(state: .submitted, timestamp: Date()))
            try await taskStore.save(initialTask, context: context)
            Task { [weak self] in _ = try? await self?.drive(requestContext, queue: queue, taskManager: taskManager) }
            result = .task(initialTask)
        }

        return applyHistoryLength(result, configuration: params.configuration)
    }

    // MARK: - message/stream

    /// Sends a message and returns the executor's events as they happen.
    ///
    /// Each event is persisted and pushed to registered webhooks before reaching the caller, so a
    /// client that reads the stream sees nothing the store has not already recorded. The stream
    /// ends when the executor finishes; abandoning it cancels the executor.
    ///
    /// - Throws: `A2AServerError.unsupportedOperation` unless the agent card advertises the
    ///   streaming capability as explicitly `true`.
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

    /// Fetches a task from the caller's scope, trimmed to the requested history length.
    ///
    /// - Returns: The task, or `nil` if the caller's scope holds no such task — which the
    ///   transports report as not found.
    public func onGetTask(_ params: GetTaskRequest, context: ServerCallContext) async throws -> A2ATask? {
        guard var task = try await taskStore.get(params.id, context: context) else { return nil }
        if let length = params.historyLength {
            task.history = Array(task.history.suffix(max(0, length)))
        }
        return task
    }

    /// Lists tasks from the caller's scope. Filtering, ordering and paging are the store's.
    public func onListTasks(_ params: ListTasksRequest, context: ServerCallContext) async throws -> ListTasksResponse {
        try await taskStore.list(params, context: context)
    }

    /// Stops a running task, if the executor agrees to stop it.
    ///
    /// The running executor is interrupted and its stream closed, then `cancel` is invoked on a
    /// fresh queue and its events are folded in. The task is only reported as cancelled if that
    /// leaves it in the canceled state.
    ///
    /// - Throws: `A2AServerError.taskNotFound` if the caller's scope holds no such task;
    ///   `A2AServerError.taskNotCancelable` if it has already finished, or if the executor declined
    ///   to cancel it.
    public func onCancelTask(_ params: CancelTaskRequest, context: ServerCallContext) async throws -> A2ATask? {
        guard let task = try await taskStore.get(params.id, context: context) else {
            throw A2AServerError.taskNotFound(params.id)
        }
        if task.status.state.isTerminal {
            throw A2AServerError.taskNotCancelable(params.id)
        }
        // Interrupt the run in flight and close the stream that was carrying it.
        runningProducers[task.id]?.cancel()
        runningProducers[task.id] = nil
        await queueManager.close(task.id)

        // Run `cancel` on a queue of its own and fold whatever it publishes; the final state is
        // what decides whether the cancellation is reported as successful.
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

    /// Follows a task that is already running.
    ///
    /// The first event is always a snapshot of the task as stored, so nothing is missed between
    /// the lookup and the subscription — events published before the tap are not replayed.
    ///
    /// A task with no live queue — because its run finished, or because it was started in another
    /// process — yields that snapshot and then fails with not-found. Events are not persisted here:
    /// the run that produces them owns that.
    ///
    /// - Throws: `A2AServerError.taskNotFound` if the caller's scope holds no such task;
    ///   `A2AServerError.unsupportedOperation` if it has already finished.
    public func onSubscribeToTask(_ params: SubscribeToTaskRequest, context: ServerCallContext) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        guard let task = try await taskStore.get(params.id, context: context) else {
            throw A2AServerError.taskNotFound(params.id)
        }
        if task.status.state.isTerminal {
            throw A2AServerError.unsupportedOperation("Task \(params.id) is in terminal state: \(task.status.state)")
        }
        let queue = await queueManager.get(params.id)
        let stream = await queue?.tap()
        return AsyncThrowingStream { continuation in
            // The snapshot goes out first, before anything the queue may deliver.
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

    /// Registers a webhook for a task's events.
    ///
    /// - Throws: `A2AServerError.pushNotificationNotSupported` if no config store was supplied.
    public func onCreateTaskPushNotificationConfig(_ params: TaskPushNotificationConfig, context: ServerCallContext) async throws -> TaskPushNotificationConfig {
        guard let store = pushConfigStore else { throw A2AServerError.pushNotificationNotSupported }
        return try await store.set(params, context: context)
    }

    /// Fetches one of the caller's webhook registrations.
    ///
    /// - Throws: `A2AServerError.pushNotificationNotSupported` if no config store was supplied;
    ///   `A2AServerError.invalidParams` if the task has no registration with that id.
    public func onGetTaskPushNotificationConfig(_ params: GetTaskPushNotificationConfigRequest, context: ServerCallContext) async throws -> TaskPushNotificationConfig {
        guard let store = pushConfigStore else { throw A2AServerError.pushNotificationNotSupported }
        let configs = try await store.get(taskId: params.taskId, context: context)
        guard let match = configs.first(where: { $0.id == params.id }) else {
            throw A2AServerError.invalidParams("Push notification config not found: \(params.id)")
        }
        return match
    }

    /// Lists the caller's webhook registrations on a task. Returned in full — the page size and
    /// token in the request are ignored.
    ///
    /// - Throws: `A2AServerError.pushNotificationNotSupported` if no config store was supplied.
    public func onListTaskPushNotificationConfigs(_ params: ListTaskPushNotificationConfigsRequest, context: ServerCallContext) async throws -> ListTaskPushNotificationConfigsResponse {
        guard let store = pushConfigStore else { throw A2AServerError.pushNotificationNotSupported }
        let configs = try await store.get(taskId: params.taskId, context: context)
        return ListTaskPushNotificationConfigsResponse(configs: configs)
    }

    /// Removes one of the caller's webhook registrations. Removing one that does not exist
    /// succeeds.
    ///
    /// - Throws: `A2AServerError.pushNotificationNotSupported` if no config store was supplied.
    public func onDeleteTaskPushNotificationConfig(_ params: DeleteTaskPushNotificationConfigRequest, context: ServerCallContext) async throws {
        guard let store = pushConfigStore else { throw A2AServerError.pushNotificationNotSupported }
        try await store.delete(taskId: params.taskId, configId: params.id, context: context)
    }

    // MARK: - extended agent card

    /// Returns the extended card, which here is the same card the handler was built with — no
    /// separate authenticated card is held.
    ///
    /// - Throws: `A2AServerError.extendedAgentCardNotConfigured` unless the card advertises the
    ///   capability as explicitly `true`.
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

    /// Starts the executor and consumes its events until the task settles, persisting and pushing
    /// each one.
    @discardableResult
    private func drive(_ requestContext: RequestContext, queue: EventQueue, taskManager: TaskManager) async throws -> SendMessageResponse? {
        let stream = await queue.tap()
        let executor = self.executor
        var result: SendMessageResponse?
        // The executor is a child of this group, so cancelling the caller awaiting the send
        // propagates through the group and into the executor.
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

    /// Registers a webhook carried inline in the send configuration, filling in the task ID the
    /// client could not know. Failures are swallowed: a bad webhook must not fail the send.
    private func registerInlinePushConfig(_ params: SendMessageRequest, taskId: TaskID, context: ServerCallContext) async {
        guard let store = pushConfigStore, var config = params.configuration?.taskPushNotificationConfig else { return }
        if config.taskId == nil { config.taskId = taskId }
        _ = try? await store.set(config, context: context)
    }

    private func sendPushIfNeeded(_ taskId: TaskID, _ event: StreamResponse) async {
        guard let sender = pushSender, let store = pushConfigStore else { return }
        // Delivery crosses owner scopes: every registration on the task gets the event.
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
            // Cancellation is an ordinary end, not a failure — no failed status is published.
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

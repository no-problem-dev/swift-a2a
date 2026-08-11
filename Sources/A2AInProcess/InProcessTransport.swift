import A2ACore
import A2AClientCore
import A2AServer

/// Connects the client protocol directly to a server handler in the same process.
///
/// Values are passed as Swift types, never encoded, so nothing here exercises the JSON layer —
/// a payload that would fail to serialize will pass unnoticed. Moving to a remote agent later is a
/// change of transport and nothing else.
///
/// Error mapping is deliberately narrow: `A2AServerError` becomes `A2AError.rpc` with the same
/// code, matching what a remote binding would produce, while any other error thrown by the handler
/// propagates unchanged rather than being wrapped.
public struct InProcessTransport: A2ATransport {
    private let handler: any RequestHandler
    private let context: ServerCallContext

    public init(handler: any RequestHandler, context: ServerCallContext = ServerCallContext()) {
        self.handler = handler
        self.context = context
    }

    public func sendMessage(_ request: SendMessageRequest) async throws -> SendMessageResponse {
        try await mapping { try await handler.onMessageSend(request, context: context) }
    }

    public func sendStreamingMessage(_ request: SendMessageRequest) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        try await mapping { try await handler.onMessageSendStream(request, context: context) }
    }

    public func getTask(_ request: GetTaskRequest) async throws -> A2ATask {
        try await mapping {
            guard let task = try await handler.onGetTask(request, context: context) else {
                throw notFound(request.id)
            }
            return task
        }
    }

    public func listTasks(_ request: ListTasksRequest) async throws -> ListTasksResponse {
        try await mapping { try await handler.onListTasks(request, context: context) }
    }

    public func cancelTask(_ request: CancelTaskRequest) async throws -> A2ATask {
        try await mapping {
            guard let task = try await handler.onCancelTask(request, context: context) else {
                throw notFound(request.id)
            }
            return task
        }
    }

    public func subscribeToTask(_ request: SubscribeToTaskRequest) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        try await mapping { try await handler.onSubscribeToTask(request, context: context) }
    }

    public func createTaskPushNotificationConfig(_ config: TaskPushNotificationConfig) async throws -> TaskPushNotificationConfig {
        try await mapping { try await handler.onCreateTaskPushNotificationConfig(config, context: context) }
    }

    public func getTaskPushNotificationConfig(_ request: GetTaskPushNotificationConfigRequest) async throws -> TaskPushNotificationConfig {
        try await mapping { try await handler.onGetTaskPushNotificationConfig(request, context: context) }
    }

    public func listTaskPushNotificationConfigs(_ request: ListTaskPushNotificationConfigsRequest) async throws -> ListTaskPushNotificationConfigsResponse {
        try await mapping { try await handler.onListTaskPushNotificationConfigs(request, context: context) }
    }

    public func deleteTaskPushNotificationConfig(_ request: DeleteTaskPushNotificationConfigRequest) async throws {
        try await mapping { try await handler.onDeleteTaskPushNotificationConfig(request, context: context) }
    }

    public func getExtendedAgentCard(_ request: GetExtendedAgentCardRequest) async throws -> AgentCard {
        try await mapping { try await handler.onGetExtendedAgentCard(request, context: context) }
    }

    // Only server errors are translated; anything else escapes as thrown.
    private func mapping<R>(_ body: () async throws -> R) async throws -> R {
        do {
            return try await body()
        } catch let error as A2AServerError {
            throw A2AError.rpc(A2ARemoteError(code: error.code, message: error.message))
        }
    }

    private func notFound(_ id: TaskID) -> A2AServerError {
        .taskNotFound(id)
    }
}

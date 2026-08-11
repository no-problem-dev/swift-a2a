import A2ACore

/// The server-side counterpart of `A2ATransport`: the same eleven operations, seen from the agent.
///
/// A transport dispatcher decodes bytes and calls one of these; the handler knows nothing about
/// HTTP. Implement it yourself only to replace ``DefaultRequestHandler`` wholesale — an agent's
/// own logic belongs in an ``AgentExecutor``.
///
/// Two methods return an optional where the transport expects a value: `nil` means the task does
/// not exist, and each dispatcher turns that into the not-found error its binding calls for.
public protocol RequestHandler: Sendable {
    func onGetTask(_ params: GetTaskRequest, context: ServerCallContext) async throws -> A2ATask?
    func onListTasks(_ params: ListTasksRequest, context: ServerCallContext) async throws -> ListTasksResponse
    func onCancelTask(_ params: CancelTaskRequest, context: ServerCallContext) async throws -> A2ATask?
    func onMessageSend(_ params: SendMessageRequest, context: ServerCallContext) async throws -> SendMessageResponse
    func onMessageSendStream(_ params: SendMessageRequest, context: ServerCallContext) async throws -> AsyncThrowingStream<StreamResponse, Error>
    func onCreateTaskPushNotificationConfig(_ params: TaskPushNotificationConfig, context: ServerCallContext) async throws -> TaskPushNotificationConfig
    func onGetTaskPushNotificationConfig(_ params: GetTaskPushNotificationConfigRequest, context: ServerCallContext) async throws -> TaskPushNotificationConfig
    func onSubscribeToTask(_ params: SubscribeToTaskRequest, context: ServerCallContext) async throws -> AsyncThrowingStream<StreamResponse, Error>
    func onListTaskPushNotificationConfigs(_ params: ListTaskPushNotificationConfigsRequest, context: ServerCallContext) async throws -> ListTaskPushNotificationConfigsResponse
    func onDeleteTaskPushNotificationConfig(_ params: DeleteTaskPushNotificationConfigRequest, context: ServerCallContext) async throws
    func onGetExtendedAgentCard(_ params: GetExtendedAgentCardRequest, context: ServerCallContext) async throws -> AgentCard
}

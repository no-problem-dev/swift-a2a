import A2ACore
import A2AClientCore
import A2AServer

/// 同一プロセス内で `A2ATransport`（クライアント側）を `RequestHandler`（サーバ側）へ
/// 直結する transport。HTTP もシリアライズも介さず、Swift の型をそのまま受け渡す。
///
/// オーケストレータ（クライアント）が、別 Task で動くワーカー（サーバ側 `AgentExecutor` を
/// 包む `DefaultRequestHandler`）と、リモートと同一の A2A クライアント API で通信できる。
/// 後でリモートに切り替えたくなったら transport を REST / JSON-RPC に差し替えるだけでよい。
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

    // MARK: - Error mapping

    /// サーバ側エラーを、リモート transport と同一の `A2AError.rpc` に写像する。
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

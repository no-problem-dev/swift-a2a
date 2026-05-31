import Foundation
import A2ACore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A2A エージェントと通信する高水準クライアント。
///
/// バインディング非依存のファサードで、具体的な通信は注入された ``A2ATransport`` が担います。
/// 通常は `A2AClientREST` / `A2AClientJSONRPC` が提供する `A2AClient.rest(...)` /
/// `A2AClient.jsonRPC(...)` ファクトリ経由で生成します。
public struct A2AClient: Sendable {
    public let configuration: A2AClientConfiguration
    public let transport: any A2ATransport
    private let http: HTTPClient

    public init(transport: any A2ATransport, http: HTTPClient, configuration: A2AClientConfiguration) {
        self.transport = transport
        self.http = http
        self.configuration = configuration
    }

    // MARK: - Messaging

    /// メッセージを送信し、完了結果（タスクまたはメッセージ）を取得。
    public func sendMessage(
        _ message: Message,
        configuration: SendMessageConfiguration? = nil,
        metadata: A2AMetadata? = nil
    ) async throws -> SendMessageResponse {
        try await transport.sendMessage(
            SendMessageRequest(message: message, configuration: configuration, metadata: metadata)
        )
    }

    /// リクエストを直接指定してメッセージを送信。
    public func sendMessage(_ request: SendMessageRequest) async throws -> SendMessageResponse {
        try await transport.sendMessage(request)
    }

    /// メッセージを送信し、更新を SSE ストリームで受信。
    public func streamMessage(
        _ message: Message,
        configuration: SendMessageConfiguration? = nil,
        metadata: A2AMetadata? = nil
    ) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        try await transport.sendStreamingMessage(
            SendMessageRequest(message: message, configuration: configuration, metadata: metadata)
        )
    }

    // MARK: - Tasks

    /// タスクの現在状態を取得。
    public func getTask(_ id: TaskID, historyLength: Int? = nil) async throws -> A2ATask {
        try await transport.getTask(GetTaskRequest(id: id, historyLength: historyLength))
    }

    /// タスク一覧を取得。
    public func listTasks(_ request: ListTasksRequest = ListTasksRequest()) async throws -> ListTasksResponse {
        try await transport.listTasks(request)
    }

    /// タスクをキャンセル。
    public func cancelTask(_ id: TaskID, metadata: A2AMetadata? = nil) async throws -> A2ATask {
        try await transport.cancelTask(CancelTaskRequest(id: id, metadata: metadata))
    }

    /// 非終端タスクの更新を購読。
    public func subscribeToTask(_ id: TaskID) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        try await transport.subscribeToTask(SubscribeToTaskRequest(id: id))
    }

    // MARK: - Push notification configs

    /// プッシュ通知設定を作成。
    public func createPushNotificationConfig(_ config: TaskPushNotificationConfig) async throws -> TaskPushNotificationConfig {
        try await transport.createTaskPushNotificationConfig(config)
    }

    /// プッシュ通知設定を取得。
    public func getPushNotificationConfig(taskId: TaskID, id: String) async throws -> TaskPushNotificationConfig {
        try await transport.getTaskPushNotificationConfig(
            GetTaskPushNotificationConfigRequest(taskId: taskId, id: id)
        )
    }

    /// プッシュ通知設定を一覧。
    public func listPushNotificationConfigs(taskId: TaskID) async throws -> ListTaskPushNotificationConfigsResponse {
        try await transport.listTaskPushNotificationConfigs(
            ListTaskPushNotificationConfigsRequest(taskId: taskId)
        )
    }

    /// プッシュ通知設定を削除。
    public func deletePushNotificationConfig(taskId: TaskID, id: String) async throws {
        try await transport.deleteTaskPushNotificationConfig(
            DeleteTaskPushNotificationConfigRequest(taskId: taskId, id: id)
        )
    }

    // MARK: - Agent Card

    /// `/.well-known/agent-card.json` から Agent Card を取得（バインディング非依存の GET）。
    public func fetchAgentCard() async throws -> AgentCard {
        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
            throw A2AError.invalidResponse("Invalid base URL")
        }
        components.path = A2AProtocol.agentCardWellKnownPath
        components.query = nil
        components.fragment = nil
        guard let url = components.url else {
            throw A2AError.invalidResponse("Cannot build well-known Agent Card URL")
        }

        let request = http.makeRequest(url: url, method: "GET", accept: A2AProtocol.jsonContentType)
        let (data, response) = try await http.send(request)
        guard (200...299).contains(response.statusCode) else {
            throw A2AError.http(status: response.statusCode, body: String(data: data, encoding: .utf8))
        }
        do {
            return try A2AJSON.decoder().decode(AgentCard.self, from: data)
        } catch {
            throw A2AError.decoding(error)
        }
    }

    /// 認証済み拡張 Agent Card を取得。
    public func fetchExtendedAgentCard() async throws -> AgentCard {
        try await transport.getExtendedAgentCard(GetExtendedAgentCardRequest())
    }
}

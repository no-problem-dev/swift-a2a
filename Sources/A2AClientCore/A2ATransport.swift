import A2ACore

/// A2A の抽象操作を表すトランスポート。JSON-RPC / REST / gRPC などのバインディングが実装する。
///
/// 操作とデータモデルはバインディング非依存で、各実装が具体的な HTTP マッピング・封筒・
/// エラー表現を担う（仕様 §5.1 の機能的等価性）。
public protocol A2ATransport: Sendable {
    /// メッセージを送信（非ストリーミング）。
    func sendMessage(_ request: SendMessageRequest) async throws -> SendMessageResponse

    /// メッセージを送信し、更新を SSE ストリームで受信。
    func sendStreamingMessage(_ request: SendMessageRequest) async throws -> AsyncThrowingStream<StreamResponse, Error>

    /// タスクの現在状態を取得。
    func getTask(_ request: GetTaskRequest) async throws -> A2ATask

    /// タスク一覧を取得。
    func listTasks(_ request: ListTasksRequest) async throws -> ListTasksResponse

    /// 進行中タスクをキャンセル。
    func cancelTask(_ request: CancelTaskRequest) async throws -> A2ATask

    /// 非終端タスクの更新を購読。
    func subscribeToTask(_ request: SubscribeToTaskRequest) async throws -> AsyncThrowingStream<StreamResponse, Error>

    /// プッシュ通知設定を作成。
    func createTaskPushNotificationConfig(_ config: TaskPushNotificationConfig) async throws -> TaskPushNotificationConfig

    /// プッシュ通知設定を取得。
    func getTaskPushNotificationConfig(_ request: GetTaskPushNotificationConfigRequest) async throws -> TaskPushNotificationConfig

    /// プッシュ通知設定を一覧。
    func listTaskPushNotificationConfigs(_ request: ListTaskPushNotificationConfigsRequest) async throws -> ListTaskPushNotificationConfigsResponse

    /// プッシュ通知設定を削除。
    func deleteTaskPushNotificationConfig(_ request: DeleteTaskPushNotificationConfigRequest) async throws

    /// 認証済み拡張 Agent Card を取得。
    func getExtendedAgentCard(_ request: GetExtendedAgentCardRequest) async throws -> AgentCard
}

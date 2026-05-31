import A2ACore

/// A2A サーバ実装が提供すべきリクエストハンドラ（a2a-python `RequestHandler`）。
///
/// あらゆるトランスポート（JSON-RPC / REST / gRPC）からの A2A リクエストを処理します。
/// 操作とデータ型は `A2ATransport`（クライアント側）と対称で、いずれも `A2ACore` の仕様型を用います。
public protocol RequestHandler: Sendable {
    /// `tasks/get`。タスクの状態と履歴を取得。存在しなければ `nil`。
    func onGetTask(_ params: GetTaskRequest, context: ServerCallContext) async throws -> A2ATask?

    /// `tasks/list`。条件に合うタスク一覧を取得。
    func onListTasks(_ params: ListTasksRequest, context: ServerCallContext) async throws -> ListTasksResponse

    /// `tasks/cancel`。進行中タスクのキャンセルを要求。存在しなければ `nil`。
    func onCancelTask(_ params: CancelTaskRequest, context: ServerCallContext) async throws -> A2ATask?

    /// `message/send`（非ストリーミング）。最終結果（`Task` または `Message`）を待って返す。
    func onMessageSend(_ params: SendMessageRequest, context: ServerCallContext) async throws -> SendMessageResponse

    /// `message/stream`（ストリーミング）。生成され次第イベントを流す。
    func onMessageSendStream(_ params: SendMessageRequest, context: ServerCallContext) async throws -> AsyncThrowingStream<StreamResponse, Error>

    /// `tasks/pushNotificationConfig/create`。プッシュ通知設定を作成・更新。
    func onCreateTaskPushNotificationConfig(_ params: TaskPushNotificationConfig, context: ServerCallContext) async throws -> TaskPushNotificationConfig

    /// `tasks/pushNotificationConfig/get`。プッシュ通知設定を取得。
    func onGetTaskPushNotificationConfig(_ params: GetTaskPushNotificationConfigRequest, context: ServerCallContext) async throws -> TaskPushNotificationConfig

    /// `tasks:subscribe`。進行中ストリーミングタスクのイベントを購読。
    func onSubscribeToTask(_ params: SubscribeToTaskRequest, context: ServerCallContext) async throws -> AsyncThrowingStream<StreamResponse, Error>

    /// `tasks/pushNotificationConfig/list`。プッシュ通知設定一覧を取得。
    func onListTaskPushNotificationConfigs(_ params: ListTaskPushNotificationConfigsRequest, context: ServerCallContext) async throws -> ListTaskPushNotificationConfigsResponse

    /// `tasks/pushNotificationConfig/delete`。プッシュ通知設定を削除。
    func onDeleteTaskPushNotificationConfig(_ params: DeleteTaskPushNotificationConfigRequest, context: ServerCallContext) async throws

    /// 認証済み拡張 Agent Card を取得。
    func onGetExtendedAgentCard(_ params: GetExtendedAgentCardRequest, context: ServerCallContext) async throws -> AgentCard
}

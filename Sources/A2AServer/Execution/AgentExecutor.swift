import A2ACore

/// エージェントの中核ロジックを実装するインターフェース（a2a-python `AgentExecutor`）。
///
/// 実装は `context` から必要情報を読み、`Task` / `Message` / `TaskStatusUpdateEvent` /
/// `TaskArtifactUpdateEvent`（= `StreamResponse`）を `eventQueue` に publish します。
///
/// ## ライフサイクルと責務
/// - **単一実行**: framework は同一リクエストに対し `execute` を並行呼び出ししない。
/// - **終端状態**: 正常終了前に終端状態（completed/failed/canceled/rejected）または
///   中断状態（input-required/auth-required）への `TaskStatusUpdateEvent` を publish すべき。
/// - **input-required**: `TaskState.inputRequired` の status を publish して return する。
///   ユーザー入力が来たら framework が再度 `execute` を呼ぶ。
/// - **例外**: `execute` が throw すると framework がタスクを失敗状態へ遷移させる。
/// - **完了後**: `execute` の戻り後は `context`/`eventQueue` にアクセスしない。
public protocol AgentExecutor: Sendable {
    /// 指定リクエストに対するエージェントロジックを実行する。
    func execute(_ context: RequestContext, eventQueue: EventQueue) async throws

    /// 進行中タスクのキャンセルを要求する。
    ///
    /// `context` の task を停止し、`TaskState.canceled` の `TaskStatusUpdateEvent` を
    /// `eventQueue` に publish すること。
    func cancel(_ context: RequestContext, eventQueue: EventQueue) async throws
}

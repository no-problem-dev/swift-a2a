import A2ACore

/// エージェントの中核ロジック（a2a-python `AgentExecutor`）。
///
/// `execute` は `context` を読み `StreamResponse` を `eventQueue` へ publish する。終端状態
/// （completed/failed/canceled/rejected）または中断状態（input-required/auth-required）を
/// publish して return すること。input-required の場合、入力到来時に framework が再度 `execute`
/// を呼ぶ。`execute` が throw すると framework がタスクを失敗状態へ遷移させる。
public protocol AgentExecutor: Sendable {
    func execute(_ context: RequestContext, eventQueue: EventQueue) async throws

    /// 進行中タスクを停止し、`TaskState.canceled` を publish する。
    func cancel(_ context: RequestContext, eventQueue: EventQueue) async throws
}

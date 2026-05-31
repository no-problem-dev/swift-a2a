/// タスクのライフサイクル状態（A2A `TaskState`）。
///
/// ProtoJSON では `TASK_STATE_SUBMITTED` などとして表現されます。
public enum TaskState: String, ProtoEnum {
    /// 未指定・不定（未知値のフォールバック先）。
    case unspecified = "TASK_STATE_UNSPECIFIED"
    /// 送信され受理された。
    case submitted = "TASK_STATE_SUBMITTED"
    /// エージェントが処理中。
    case working = "TASK_STATE_WORKING"
    /// 正常完了（終端状態）。
    case completed = "TASK_STATE_COMPLETED"
    /// エラーで終了（終端状態）。
    case failed = "TASK_STATE_FAILED"
    /// 完了前にキャンセルされた（終端状態）。
    case canceled = "TASK_STATE_CANCELED"
    /// 続行にユーザー入力が必要（中断状態）。
    case inputRequired = "TASK_STATE_INPUT_REQUIRED"
    /// エージェントがタスク実行を拒否した（終端状態）。
    case rejected = "TASK_STATE_REJECTED"
    /// 続行に認証が必要（中断状態）。
    case authRequired = "TASK_STATE_AUTH_REQUIRED"

    /// 終端状態（completed / failed / canceled / rejected）かどうか。
    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .canceled, .rejected: true
        default: false
        }
    }

    /// 中断状態（inputRequired / authRequired）かどうか。
    public var isInterrupted: Bool {
        switch self {
        case .inputRequired, .authRequired: true
        default: false
        }
    }
}

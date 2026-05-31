import A2ACore

/// A2A サーバ側のエラー（A2A 仕様 §5.4 のエラーコードに対応）。
///
/// Python `a2a.utils.errors` の各エラーに相当します。バインディング層が
/// これを JSON-RPC error / google.rpc.Status に変換して応答します。
public enum A2AServerError: Error, Sendable, Hashable {
    /// 指定タスクが見つからない（`-32001`）。
    case taskNotFound(TaskID)
    /// タスクがキャンセル不能な状態にある（`-32002`）。
    case taskNotCancelable(TaskID)
    /// プッシュ通知が未対応（`-32003`）。
    case pushNotificationNotSupported
    /// 要求された操作が未対応（`-32004`）。
    case unsupportedOperation(String)
    /// コンテンツタイプ非対応（`-32005`）。
    case contentTypeNotSupported
    /// エージェントの応答が不正（`-32006`）。
    case invalidAgentResponse(String)
    /// 拡張 Agent Card 未設定（`-32007`）。
    case extendedAgentCardNotConfigured
    /// パラメータ不正（`-32602`）。
    case invalidParams(String)
    /// 内部エラー（`-32603`）。
    case internalError(String)

    /// A2A 仕様のエラーコード。
    public var code: Int {
        switch self {
        case .taskNotFound: -32001
        case .taskNotCancelable: -32002
        case .pushNotificationNotSupported: -32003
        case .unsupportedOperation: -32004
        case .contentTypeNotSupported: -32005
        case .invalidAgentResponse: -32006
        case .extendedAgentCardNotConfigured: -32007
        case .invalidParams: -32602
        case .internalError: -32603
        }
    }

    /// 人間可読なメッセージ。
    public var message: String {
        switch self {
        case .taskNotFound(let id): "Task not found: \(id)"
        case .taskNotCancelable(let id): "Task not cancelable: \(id)"
        case .pushNotificationNotSupported: "Push Notification is not supported"
        case .unsupportedOperation(let detail): "Unsupported operation: \(detail)"
        case .contentTypeNotSupported: "Incompatible content types"
        case .invalidAgentResponse(let detail): "Invalid agent response: \(detail)"
        case .extendedAgentCardNotConfigured: "Extended agent card is not configured"
        case .invalidParams(let detail): "Invalid parameters: \(detail)"
        case .internalError(let detail): "Internal error: \(detail)"
        }
    }
}

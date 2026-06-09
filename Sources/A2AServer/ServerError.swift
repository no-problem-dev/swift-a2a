import A2ACore

/// A2A サーバ側のエラー（仕様 §5.4 のコードに対応、a2a-python `a2a.utils.errors` 相当）。
public enum A2AServerError: Error, Sendable, Hashable {
    case taskNotFound(TaskID)
    case taskNotCancelable(TaskID)
    case pushNotificationNotSupported
    case unsupportedOperation(String)
    case contentTypeNotSupported
    case invalidAgentResponse(String)
    case extendedAgentCardNotConfigured
    case extensionSupportRequired
    case versionNotSupported(String)
    case invalidParams(String)
    case internalError(String)

    public var code: Int {
        switch self {
        case .taskNotFound: -32001
        case .taskNotCancelable: -32002
        case .pushNotificationNotSupported: -32003
        case .unsupportedOperation: -32004
        case .contentTypeNotSupported: -32005
        case .invalidAgentResponse: -32006
        case .extendedAgentCardNotConfigured: -32007
        case .extensionSupportRequired: -32008
        case .versionNotSupported: -32009
        case .invalidParams: -32602
        case .internalError: -32603
        }
    }

    public var message: String {
        switch self {
        case .taskNotFound(let id): "Task not found: \(id)"
        case .taskNotCancelable(let id): "Task not cancelable: \(id)"
        case .pushNotificationNotSupported: "Push Notification is not supported"
        case .unsupportedOperation(let detail): "Unsupported operation: \(detail)"
        case .contentTypeNotSupported: "Incompatible content types"
        case .invalidAgentResponse(let detail): "Invalid agent response: \(detail)"
        case .extendedAgentCardNotConfigured: "Extended agent card is not configured"
        case .extensionSupportRequired: "Extension support required"
        case .versionNotSupported(let detail): "Version not supported: \(detail)"
        case .invalidParams(let detail): "Invalid parameters: \(detail)"
        case .internalError(let detail): "Internal error: \(detail)"
        }
    }
}

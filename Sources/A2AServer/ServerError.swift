import A2ACore

/// The failures a handler reports, each carrying the A2A error code the specification assigns it
/// (§5.4).
///
/// The transport dispatchers translate these: JSON-RPC sends the code as-is, while REST maps it to
/// an HTTP status as well. An error of any other type becomes a generic internal error, losing its
/// detail — so throw one of these from an executor when the failure should reach the client
/// meaningfully.
public enum A2AServerError: Error, Sendable, Hashable {
    /// No task with that ID in the caller's scope.
    case taskNotFound(TaskID)
    /// The task cannot be stopped — it has already finished, or the executor declined.
    case taskNotCancelable(TaskID)
    /// No push notification store is configured, so webhooks cannot be registered.
    case pushNotificationNotSupported
    /// The agent does not offer this operation, or not for this task's current state.
    case unsupportedOperation(String)
    /// The content the client sent, or asked for, is not something the agent handles.
    case contentTypeNotSupported
    /// The executor produced something that does not fit the protocol.
    case invalidAgentResponse(String)
    /// The agent does not publish an extended card.
    case extendedAgentCardNotConfigured
    /// The caller must opt into an extension the agent requires.
    case extensionSupportRequired
    /// The protocol version the caller asked for is not served.
    case versionNotSupported(String)
    /// The request decoded but its contents are unusable.
    case invalidParams(String)
    /// Anything else. The detail reaches the client, so keep it free of internals.
    case internalError(String)

    /// The A2A error code for this failure.
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

    /// A message for people to read. Clients should branch on `code`, not on this.
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

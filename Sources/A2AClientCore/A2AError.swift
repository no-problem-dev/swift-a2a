import Foundation
import StructuredDataCore

/// Everything a client call can fail with, whichever binding produced it.
///
/// The distinction that matters is `rpc` versus `http`: the first means the agent answered with a
/// structured A2A error and the code is meaningful; the second means it did not, and only the
/// status is known.
public enum A2AError: Error, Sendable {
    /// The agent reported a structured error. Inspect the code and reason.
    case rpc(A2ARemoteError)
    /// A non-2xx response whose body was not a structured A2A error.
    case http(status: Int, body: String?)
    /// The response carried neither a result nor an error, which the protocol does not allow.
    case emptyResult
    /// The response was well-formed HTTP but not something this client can use.
    case invalidResponse(String)
    /// The response body did not match the expected shape.
    case decoding(any Error)
    /// The request could not be serialized. The call never left the process.
    case encoding(any Error)
    /// The request exceeded its timeout — the streaming one for streams, the normal one otherwise.
    case timeout
    /// The connection failed for any other reason.
    case transport(any Error)
}

/// A structured error from the agent, with the JSON-RPC error object and the REST `google.rpc.Status`
/// body reduced to one shape.
public struct A2ARemoteError: Error, Sendable, Hashable {
    /// The error code. A JSON-RPC code such as `-32001` when the agent supplied one; otherwise the
    /// HTTP status, which the REST binding substitutes when the body omits a code.
    public var code: Int
    /// The agent's message, for people to read. Never match on this — match on `code` or `reason`.
    public var message: String
    /// Detail objects, each tagged with `@type` in the ProtoJSON encoding of `Any`.
    public var details: [StructuredValue]

    public init(code: Int, message: String, details: [StructuredValue] = []) {
        self.code = code
        self.message = message
        self.details = details
    }

    // The standard JSON-RPC codes.
    public static let parseError = -32700
    public static let invalidRequest = -32600
    public static let methodNotFound = -32601
    public static let invalidParams = -32602
    public static let internalError = -32603

    // The A2A-specific codes (spec §5.4).
    public static let taskNotFound = -32001
    public static let taskNotCancelable = -32002
    public static let pushNotificationNotSupported = -32003
    public static let unsupportedOperation = -32004
    public static let contentTypeNotSupported = -32005
    public static let invalidAgentResponse = -32006
    public static let extendedAgentCardNotConfigured = -32007
    public static let extensionSupportRequired = -32008
    public static let versionNotSupported = -32009

    /// The machine-readable reason from the error details, such as `TASK_NOT_FOUND` — the value
    /// to branch on, since codes are reused and messages are prose.
    ///
    /// Returns the first `reason` found in any detail object. The detail's `@type` is not checked,
    /// so a non-`ErrorInfo` detail that happens to carry a `reason` key will be picked up.
    public var reason: String? {
        for detail in details {
            if case .object(let object) = detail,
               let reason = object["reason"]?.stringValue {
                return reason
            }
        }
        return nil
    }
}

extension A2AError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .rpc(let error):
            return "A2A error \(error.code): \(error.message)"
        case .http(let status, let body):
            return "HTTP error \(status): \(body ?? "no body")"
        case .emptyResult:
            return "Empty result from A2A server"
        case .invalidResponse(let detail):
            return "Invalid A2A response: \(detail)"
        case .decoding(let error):
            return "Failed to decode A2A response: \(error.localizedDescription)"
        case .encoding(let error):
            return "Failed to encode A2A request: \(error.localizedDescription)"
        case .timeout:
            return "Request timed out"
        case .transport(let error):
            return "Connection error: \(error.localizedDescription)"
        }
    }
}

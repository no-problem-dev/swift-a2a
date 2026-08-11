import Foundation

/// Everything a client needs to reach one agent: where it is, how to authenticate, how long to
/// wait, and which extensions to opt into.
public struct A2AClientConfiguration: Sendable {
    /// The endpoint. For JSON-RPC this is the single URL every request is posted to; for REST it
    /// is the prefix each operation path is appended to. Agent-card lookup ignores the path
    /// entirely and goes to the host's well-known location.
    public var baseURL: URL
    /// What to send to prove who the client is.
    public var authentication: A2AAuthentication
    /// Seconds to wait on a non-streaming request.
    public var timeout: TimeInterval
    /// Seconds to wait on a streaming request. Longer than `timeout` by default, since a stream is
    /// expected to stay open. This is a whole-request budget, not an idle timeout, so a stream that
    /// legitimately runs longer will be cut off.
    public var streamTimeout: TimeInterval
    /// Extension URIs to declare in the `A2A-Extensions` header, comma-separated on the wire.
    public var extensions: [String]

    public init(
        baseURL: URL,
        authentication: A2AAuthentication = .none,
        timeout: TimeInterval = 60,
        streamTimeout: TimeInterval = 300,
        extensions: [String] = []
    ) {
        self.baseURL = baseURL
        self.authentication = authentication
        self.timeout = timeout
        self.streamTimeout = streamTimeout
        self.extensions = extensions
    }
}

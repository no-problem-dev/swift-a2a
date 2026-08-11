import Foundation
import A2ACore
import A2AClientCore

extension A2AClient {
    /// Creates a client that speaks the JSON-RPC 2.0 binding.
    ///
    /// Every operation is a POST to the one endpoint, distinguished by the method name in the
    /// envelope. Agent-card lookup still goes to the host's well-known path, ignoring this URL's
    /// own path.
    ///
    /// - Parameters:
    ///   - endpoint: The URL every request is posted to.
    ///   - authentication: What to send to prove who the client is.
    ///   - timeout: Seconds to wait on a non-streaming request.
    ///   - streamTimeout: Seconds to wait on a streaming request.
    ///   - extensions: Extension URIs to declare on every request.
    public static func jsonRPC(
        endpoint: URL,
        authentication: A2AAuthentication = .none,
        timeout: TimeInterval = 60,
        streamTimeout: TimeInterval = 300,
        extensions: [String] = []
    ) -> A2AClient {
        let configuration = A2AClientConfiguration(
            baseURL: endpoint,
            authentication: authentication,
            timeout: timeout,
            streamTimeout: streamTimeout,
            extensions: extensions
        )
        let http = HTTPClient(configuration: configuration)
        let transport = JSONRPCTransport(http: http, endpoint: endpoint)
        return A2AClient(transport: transport, http: http, configuration: configuration)
    }
}

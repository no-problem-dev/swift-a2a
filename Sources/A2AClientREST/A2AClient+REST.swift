import Foundation
import A2ACore
import A2AClientCore

extension A2AClient {
    /// Creates a client that speaks the HTTP+JSON binding.
    ///
    /// Each operation is its own path and verb under the base URL. A trailing slash on the base
    /// URL is trimmed, so both spellings behave the same. Agent-card lookup ignores this URL's
    /// path and goes to the host's well-known location.
    ///
    /// - Parameters:
    ///   - baseURL: The prefix each operation path is appended to.
    ///   - authentication: What to send to prove who the client is.
    ///   - timeout: Seconds to wait on a non-streaming request.
    ///   - streamTimeout: Seconds to wait on a streaming request.
    ///   - extensions: Extension URIs to declare on every request.
    public static func rest(
        baseURL: URL,
        authentication: A2AAuthentication = .none,
        timeout: TimeInterval = 60,
        streamTimeout: TimeInterval = 300,
        extensions: [String] = []
    ) -> A2AClient {
        let configuration = A2AClientConfiguration(
            baseURL: baseURL,
            authentication: authentication,
            timeout: timeout,
            streamTimeout: streamTimeout,
            extensions: extensions
        )
        let http = HTTPClient(configuration: configuration)
        let transport = RESTTransport(http: http, baseURL: baseURL)
        return A2AClient(transport: transport, http: http, configuration: configuration)
    }
}

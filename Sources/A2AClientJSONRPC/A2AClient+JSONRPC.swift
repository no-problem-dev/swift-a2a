import Foundation
import A2ACore
import A2AClientCore

extension A2AClient {
    /// JSON-RPC バインディングの A2A クライアントを生成。
    ///
    /// - Parameters:
    ///   - endpoint: JSON-RPC リクエストを POST する URL。
    ///   - authentication: 認証方式。
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

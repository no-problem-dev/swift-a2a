import Foundation
import A2ACore
import A2AClientCore

extension A2AClient {
    /// HTTP+JSON / REST バインディングの A2A クライアントを生成。
    ///
    /// - Parameters:
    ///   - baseURL: 各操作パス（`/message:send` 等）を連結するベース URL。
    ///   - authentication: 認証方式。
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

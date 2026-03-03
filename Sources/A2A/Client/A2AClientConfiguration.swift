import Foundation

// MARK: - A2AClientConfiguration

/// A2Aクライアントの設定
public struct A2AClientConfiguration: Sendable {
    /// ベースURL
    public let baseURL: URL

    /// 認証設定
    public let authentication: A2AAuthentication

    /// 通常リクエストのタイムアウト（秒）
    public let timeout: TimeInterval

    /// ストリーミングリクエストのタイムアウト（秒）
    public let streamTimeout: TimeInterval

    public init(
        baseURL: URL,
        authentication: A2AAuthentication = .none,
        timeout: TimeInterval = 60,
        streamTimeout: TimeInterval = 300
    ) {
        self.baseURL = baseURL
        self.authentication = authentication
        self.timeout = timeout
        self.streamTimeout = streamTimeout
    }
}

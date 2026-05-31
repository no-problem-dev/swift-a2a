import Foundation

/// A2A クライアントの設定。
public struct A2AClientConfiguration: Sendable {
    /// バインディングのエンドポイント。JSON-RPC では POST 先の単一 URL、
    /// REST では各操作パスを連結するベース URL。
    public var baseURL: URL
    /// 認証方式。
    public var authentication: A2AAuthentication
    /// 通常リクエストのタイムアウト（秒）。
    public var timeout: TimeInterval
    /// ストリーミングリクエストのタイムアウト（秒）。
    public var streamTimeout: TimeInterval
    /// オプトインする拡張の URI 一覧（`A2A-Extensions` ヘッダ）。
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

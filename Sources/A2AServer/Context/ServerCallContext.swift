import A2ACore

/// サーバが 1 リクエストの処理に渡す呼び出しコンテキスト（A2A `ServerCallContext`）。
///
/// 認証済みユーザー・任意の状態・拡張ネゴシエーション結果などを保持し、
/// トランスポート層から `RequestHandler` へ受け渡されます。
public struct ServerCallContext: Sendable {
    /// 認証済みの呼び出し元（未認証なら `nil`）。
    public var user: ServerUser?
    /// リクエストスコープの任意状態。
    public var state: [String: String]
    /// クライアントが要求した拡張 URI 一覧。
    public var requestedExtensions: Set<String>
    /// サーバが実際に有効化した拡張 URI 一覧。
    public var activatedExtensions: Set<String>

    public init(
        user: ServerUser? = nil,
        state: [String: String] = [:],
        requestedExtensions: Set<String> = [],
        activatedExtensions: Set<String> = []
    ) {
        self.user = user
        self.state = state
        self.requestedExtensions = requestedExtensions
        self.activatedExtensions = activatedExtensions
    }
}

/// 認証済みユーザー（A2A `User`）。
public struct ServerUser: Sendable, Hashable {
    /// 認証済みかどうか。
    public var isAuthenticated: Bool
    /// ユーザー名・識別子。
    public var username: String?

    public init(isAuthenticated: Bool = false, username: String? = nil) {
        self.isAuthenticated = isAuthenticated
        self.username = username
    }
}

import A2ACore

/// サーバが 1 リクエスト処理に渡す呼び出しコンテキスト（A2A `ServerCallContext`）。
public struct ServerCallContext: Sendable {
    public var user: ServerUser?
    public var state: [String: String]
    public var requestedExtensions: Set<String>
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

/// リクエストの認証済みユーザ情報。
///
/// `isAuthenticated` が認証の可否を示し、`username` はオプションのユーザ識別子。
public struct ServerUser: Sendable, Hashable {
    public var isAuthenticated: Bool
    public var username: String?

    public init(isAuthenticated: Bool = false, username: String? = nil) {
        self.isAuthenticated = isAuthenticated
        self.username = username
    }
}

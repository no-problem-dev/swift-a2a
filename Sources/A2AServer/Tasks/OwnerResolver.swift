/// 呼び出しコンテキストから所有者スコープ（owner）を導出する（a2a-python `OwnerResolver`）。
///
/// store はこの owner ごとにデータを分離し、spec §254/§13.1 の認可スコープ要件を満たす。
public typealias OwnerResolver = @Sendable (ServerCallContext) -> String

/// 既定の owner 解決（a2a-python `resolve_user_scope`）。
/// 認証ユーザ名を owner とし、未認証は空文字（単一スコープ）。
public let resolveUserScope: OwnerResolver = { $0.user?.username ?? "" }

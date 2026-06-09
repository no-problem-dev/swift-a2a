/// A2A プロトコルの定数。
public enum A2AProtocol {
    /// このライブラリが実装する A2A プロトコルのバージョン（spec v1.0.1 / a2a-python v1.1.0 準拠）。
    public static let version = "1.0.1"

    /// Agent Card を公開する well-known パス（仕様 §14.3）。
    public static let agentCardWellKnownPath = "/.well-known/agent-card.json"

    /// JSON-RPC バインディングのメディアタイプ。
    public static let jsonContentType = "application/json"

    /// HTTP+JSON / REST バインディングのメディアタイプ（仕様 §14.1）。
    public static let a2aJSONContentType = "application/a2a+json"

    /// プロトコルバージョンを伝える HTTP ヘッダ名（仕様 §14.2.1）。
    public static let versionHeader = "A2A-Version"

    /// 利用拡張を伝える HTTP ヘッダ名（仕様 §14.2.2）。
    public static let extensionsHeader = "A2A-Extensions"
}

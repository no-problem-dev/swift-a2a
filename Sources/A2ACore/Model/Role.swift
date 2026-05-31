/// メッセージの送信者（A2A `Role`）。
///
/// ProtoJSON では `ROLE_USER` / `ROLE_AGENT` として表現されます。
public enum Role: String, ProtoEnum {
    /// 未指定（未知値のフォールバック先）。
    case unspecified = "ROLE_UNSPECIFIED"
    /// クライアント（リクエスター）からのメッセージ。
    case user = "ROLE_USER"
    /// エージェント（レスポンダー）からのメッセージ。
    case agent = "ROLE_AGENT"
}

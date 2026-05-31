/// ProtoJSON で `SCREAMING_SNAKE_CASE` の文字列名としてシリアライズされる enum 共通実装。
///
/// A2A 仕様 §5.5 に従い、enum 値は Protocol Buffer 定義の名前（例 `ROLE_USER`,
/// `TASK_STATE_INPUT_REQUIRED`）として表現されます。未知の値は前方互換性のため
/// `unspecified` ケースへフォールバックします（§5.7 "ignore unrecognized"）。
public protocol ProtoEnum: RawRepresentable, Codable, Sendable, Hashable, CaseIterable
where RawValue == String {
    /// 未知値・未指定をデコードした際のフォールバック先。
    static var unspecified: Self { get }
}

extension ProtoEnum {
    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? Self.unspecified
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

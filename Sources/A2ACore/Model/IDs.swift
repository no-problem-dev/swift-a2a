/// 型付き ID。生の `String` を取り違えないための薄いラッパ。
///
/// JSON 上は素の文字列として透過的に符号化されます。
public protocol A2AIdentifier: RawRepresentable, Codable, Sendable, Hashable,
    ExpressibleByStringLiteral, CustomStringConvertible
where RawValue == String {
    init(_ rawValue: String)
}

extension A2AIdentifier {
    public init(_ rawValue: String) { self.init(rawValue: rawValue)! }
    public init(stringLiteral value: String) { self.init(value) }
    public init(from decoder: any Decoder) throws {
        self.init(try decoder.singleValueContainer().decode(String.self))
    }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
    public var description: String { rawValue }
}

/// タスク識別子。
public struct TaskID: A2AIdentifier {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

/// コンテキスト（会話・セッション）識別子。
public struct ContextID: A2AIdentifier {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

/// メッセージ識別子。
public struct MessageID: A2AIdentifier {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

/// アーティファクト識別子。
public struct ArtifactID: A2AIdentifier {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

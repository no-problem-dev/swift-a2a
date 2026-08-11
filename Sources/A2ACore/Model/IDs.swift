/// A string identifier wrapped in its own type, so a task ID cannot be passed where a context ID
/// is expected.
///
/// On the wire these are plain strings — the wrapper exists only in Swift. Any string is accepted,
/// including the empty one, which is how a missing required ID is represented after decoding.
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

/// Identifies a task. Assigned by the server.
public struct TaskID: A2AIdentifier {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

/// Groups tasks and messages that belong to one ongoing conversation.
public struct ContextID: A2AIdentifier {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

/// Identifies a message. Assigned by whoever creates it.
public struct MessageID: A2AIdentifier {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

/// Identifies an artifact, uniquely within its task.
public struct ArtifactID: A2AIdentifier {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

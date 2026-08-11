import Foundation

/// Assembles a message's parts from a block, so multi-part content reads as a list rather than an
/// array literal.
///
/// A bare string becomes a text part, `if` and `for` are supported, and an array of parts splices
/// in as its elements.
///
/// ```swift
/// let message = Message(role: .user) {
///     "What is the weather?"
///     Part.file(uri: "https://example.com/map.png", mediaType: "image/png")
/// }
/// ```
@resultBuilder
public enum PartBuilder {
    public static func buildExpression(_ part: Part) -> [Part] { [part] }
    public static func buildExpression(_ text: String) -> [Part] { [.text(text)] }
    public static func buildExpression(_ parts: [Part]) -> [Part] { parts }
    public static func buildBlock(_ components: [Part]...) -> [Part] { components.flatMap { $0 } }
    public static func buildArray(_ components: [[Part]]) -> [Part] { components.flatMap { $0 } }
    public static func buildOptional(_ component: [Part]?) -> [Part] { component ?? [] }
    public static func buildEither(first component: [Part]) -> [Part] { component }
    public static func buildEither(second component: [Part]) -> [Part] { component }
}

extension Message {
    /// Creates a message whose parts come from a builder block.
    ///
    /// A fresh UUID is generated for `messageId` unless one is supplied — note that the default is
    /// evaluated per call, so each message gets its own.
    public init(
        messageId: MessageID = MessageID(UUID().uuidString),
        role: Role,
        contextId: ContextID? = nil,
        taskId: TaskID? = nil,
        metadata: A2AMetadata? = nil,
        @PartBuilder parts: () -> [Part]
    ) {
        self.init(
            messageId: messageId,
            role: role,
            parts: parts(),
            contextId: contextId,
            taskId: taskId,
            metadata: metadata
        )
    }

    /// Creates a single-text-part message from the client.
    public static func user(_ text: String, messageId: MessageID = MessageID(UUID().uuidString)) -> Message {
        Message(messageId: messageId, role: .user, parts: [.text(text)])
    }

    /// Creates a single-text-part message from the agent.
    public static func agent(_ text: String, messageId: MessageID = MessageID(UUID().uuidString)) -> Message {
        Message(messageId: messageId, role: .agent, parts: [.text(text)])
    }
}

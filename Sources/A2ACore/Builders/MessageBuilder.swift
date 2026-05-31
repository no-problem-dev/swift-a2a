import Foundation

/// パート列を宣言的に組み立てる Result Builder。
///
/// 文字列リテラルは自動的にテキストパートになります。
///
/// ```swift
/// let message = Message(role: .user) {
///     "天気を教えて"
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
    /// ビルダーでパートを組み立ててメッセージを作成。`messageId` 省略時は UUID を採番。
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

    /// ユーザーからのテキストメッセージを簡易作成。
    public static func user(_ text: String, messageId: MessageID = MessageID(UUID().uuidString)) -> Message {
        Message(messageId: messageId, role: .user, parts: [.text(text)])
    }

    /// エージェントからのテキストメッセージを簡易作成。
    public static func agent(_ text: String, messageId: MessageID = MessageID(UUID().uuidString)) -> Message {
        Message(messageId: messageId, role: .agent, parts: [.text(text)])
    }
}

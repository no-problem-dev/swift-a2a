/// One turn of the exchange between a client and an agent.
///
/// Setting `taskId` on an outgoing message continues that task rather than starting a new one —
/// which is how a client answers an agent that stopped in an input-required state.
public struct Message: Sendable, Hashable {
    /// Identifies this message. The sender assigns it.
    public var messageId: MessageID
    /// Whether the client or the agent sent this.
    public var role: Role
    /// The content, as one or more parts.
    public var parts: [Part]
    /// The conversation this message belongs to. The server assigns one if it is absent.
    public var contextId: ContextID?
    /// The task this message continues. Absent means a new task.
    public var taskId: TaskID?
    /// Free-form data carried alongside the content.
    public var metadata: A2AMetadata?
    /// URIs of the protocol extensions in play for this message.
    public var extensions: [String]
    /// Other tasks the agent should consider as context for this one.
    public var referenceTaskIds: [TaskID]

    public init(
        messageId: MessageID,
        role: Role,
        parts: [Part],
        contextId: ContextID? = nil,
        taskId: TaskID? = nil,
        metadata: A2AMetadata? = nil,
        extensions: [String] = [],
        referenceTaskIds: [TaskID] = []
    ) {
        self.messageId = messageId
        self.role = role
        self.parts = parts
        self.contextId = contextId
        self.taskId = taskId
        self.metadata = metadata
        self.extensions = extensions
        self.referenceTaskIds = referenceTaskIds
    }
}

extension Message: Codable {
    private enum CodingKeys: String, CodingKey {
        case messageId, role, parts, contextId, taskId, metadata, extensions, referenceTaskIds
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        messageId = try container.decodeID(forKey: .messageId)
        role = try container.decodeProtoEnum(forKey: .role)
        parts = try container.decodeArray(forKey: .parts)
        contextId = try container.decodeOptionalID(forKey: .contextId)
        taskId = try container.decodeOptionalID(forKey: .taskId)
        metadata = try container.decodeIfPresent(A2AMetadata.self, forKey: .metadata)
        extensions = try container.decodeArray(forKey: .extensions)
        referenceTaskIds = try container.decodeArray(forKey: .referenceTaskIds)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfNonEmpty(messageId, forKey: .messageId)
        try container.encode(proto: role, forKey: .role)
        try container.encodeIfNonEmpty(parts, forKey: .parts)
        try container.encodeIfPresent(contextId, forKey: .contextId)
        try container.encodeIfPresent(taskId, forKey: .taskId)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encodeIfNonEmpty(extensions, forKey: .extensions)
        try container.encodeIfNonEmpty(referenceTaskIds, forKey: .referenceTaskIds)
    }
}

// MARK: - Accessors

extension Message {
    /// The text parts joined with no separator; non-text parts are skipped.
    public var text: String {
        parts.compactMap(\.text).joined()
    }
}

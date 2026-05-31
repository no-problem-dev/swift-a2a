/// クライアントとエージェント間の通信単位（A2A `Message`）。
public struct Message: Sendable, Hashable {
    /// メッセージの一意識別子（作成者が採番）。
    public var messageId: MessageID
    /// 送信者の役割。
    public var role: Role
    /// メッセージ本体を構成するパート（1つ以上）。
    public var parts: [Part]
    /// 関連付けるコンテキスト ID。
    public var contextId: ContextID?
    /// 関連付けるタスク ID。
    public var taskId: TaskID?
    /// 付随メタデータ。
    public var metadata: A2AMetadata?
    /// このメッセージに関与する拡張の URI 一覧。
    public var extensions: [String]
    /// 追加コンテキストとして参照するタスク ID 一覧。
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
    /// 全テキストパートを連結した文字列。
    public var text: String {
        parts.compactMap(\.text).joined()
    }
}

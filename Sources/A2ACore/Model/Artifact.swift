/// タスクの出力成果物（A2A `Artifact`）。
public struct Artifact: Sendable, Hashable {
    /// アーティファクトの一意識別子（タスク内で一意）。
    public var artifactId: ArtifactID
    /// 人間可読な名前。
    public var name: String?
    /// 人間可読な説明。
    public var description: String?
    /// 成果物の内容（1つ以上のパート）。
    public var parts: [Part]
    /// 付随メタデータ。
    public var metadata: A2AMetadata?
    /// このアーティファクトに関与する拡張の URI 一覧。
    public var extensions: [String]

    public init(
        artifactId: ArtifactID,
        name: String? = nil,
        description: String? = nil,
        parts: [Part],
        metadata: A2AMetadata? = nil,
        extensions: [String] = []
    ) {
        self.artifactId = artifactId
        self.name = name
        self.description = description
        self.parts = parts
        self.metadata = metadata
        self.extensions = extensions
    }
}

extension Artifact: Codable {
    private enum CodingKeys: String, CodingKey {
        case artifactId, name, description, parts, metadata, extensions
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        artifactId = try container.decodeID(forKey: .artifactId)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        parts = try container.decodeArray(forKey: .parts)
        metadata = try container.decodeIfPresent(A2AMetadata.self, forKey: .metadata)
        extensions = try container.decodeArray(forKey: .extensions)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfNonEmpty(artifactId, forKey: .artifactId)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfNonEmpty(parts, forKey: .parts)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encodeIfNonEmpty(extensions, forKey: .extensions)
    }
}

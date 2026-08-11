/// Something a task produced.
///
/// An artifact can arrive in pieces: a streaming agent sends the same `artifactId` repeatedly with
/// `append` set, and the recipient concatenates the parts.
public struct Artifact: Sendable, Hashable {
    /// Identifies this artifact within its task, and is what ties streamed chunks together.
    public var artifactId: ArtifactID
    /// A name for people to read.
    public var name: String?
    /// A description for people to read.
    public var description: String?
    /// The content, as one or more parts.
    public var parts: [Part]
    /// Free-form data carried alongside the content.
    public var metadata: A2AMetadata?
    /// URIs of the protocol extensions in play for this artifact.
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

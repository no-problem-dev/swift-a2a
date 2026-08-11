import Foundation
import StructuredDataCore

/// A piece of content inside a message or an artifact.
///
/// v1.0 dropped the discriminator field earlier revisions carried (`type`, then `kind`). The
/// content kind is now the JSON member name itself — `text`, `raw`, `url` or `data` — while
/// `filename`, `mediaType` and `metadata` sit alongside it and apply to any kind.
///
/// Decoding rejects an object carrying none of the four content members. It does not reject one
/// carrying several: the first match in the order `text`, `raw`, `url`, `data` wins and the rest
/// are dropped silently.
public struct Part: Sendable, Hashable {
    /// The four content kinds, exactly one of which a part carries.
    public enum Content: Sendable, Hashable {
        /// Plain text.
        case text(String)
        /// File contents inline, Base64-encoded on the wire (proto `raw`).
        case bytes(Data)
        /// A URI pointing at the file rather than carrying it (proto `url`).
        case uri(String)
        /// Arbitrary JSON (proto `data`), for structured payloads with no schema fixed by A2A.
        case data(StructuredValue)
    }

    /// What this part carries.
    public var content: Content
    /// Free-form data carried alongside the content.
    public var metadata: A2AMetadata?
    /// The originating file name, such as `document.pdf`.
    public var filename: String?
    /// The media type of the content, such as `text/plain` or `image/png`. Valid for every content
    /// kind, including text and structured data.
    public var mediaType: String?

    public init(
        content: Content,
        metadata: A2AMetadata? = nil,
        filename: String? = nil,
        mediaType: String? = nil
    ) {
        self.content = content
        self.metadata = metadata
        self.filename = filename
        self.mediaType = mediaType
    }
}

// MARK: - Convenience Constructors

extension Part {
    /// Creates a text part.
    public static func text(_ text: String, metadata: A2AMetadata? = nil) -> Part {
        Part(content: .text(text), metadata: metadata)
    }

    /// Creates a file part carrying the contents inline.
    ///
    /// The bytes are Base64-encoded on the wire, so this inflates the payload by roughly a third —
    /// prefer the URI form for anything large.
    public static func file(
        bytes: Data,
        filename: String? = nil,
        mediaType: String? = nil,
        metadata: A2AMetadata? = nil
    ) -> Part {
        Part(content: .bytes(bytes), metadata: metadata, filename: filename, mediaType: mediaType)
    }

    /// Creates a file part that points at the content instead of carrying it.
    ///
    /// Nothing here fetches the URI or checks that the recipient can reach it.
    public static func file(
        uri: String,
        filename: String? = nil,
        mediaType: String? = nil,
        metadata: A2AMetadata? = nil
    ) -> Part {
        Part(content: .uri(uri), metadata: metadata, filename: filename, mediaType: mediaType)
    }

    /// Creates a part carrying arbitrary JSON.
    public static func data(
        _ data: StructuredValue,
        mediaType: String? = nil,
        metadata: A2AMetadata? = nil
    ) -> Part {
        Part(content: .data(data), metadata: metadata, mediaType: mediaType)
    }
}

// MARK: - Accessors

extension Part {
    /// The text, or `nil` for any other content kind.
    public var text: String? {
        if case .text(let value) = content { return value }
        return nil
    }

    /// The inline file contents, or `nil` for any other content kind.
    public var bytes: Data? {
        if case .bytes(let value) = content { return value }
        return nil
    }

    /// The file URI, or `nil` for any other content kind.
    public var uri: String? {
        if case .uri(let value) = content { return value }
        return nil
    }

    /// The structured payload, or `nil` for any other content kind.
    public var data: StructuredValue? {
        if case .data(let value) = content { return value }
        return nil
    }
}

// MARK: - Codable (ProtoJSON oneof flattening)

extension Part: Codable {
    private enum CodingKeys: String, CodingKey {
        case text, raw, url, data, metadata, filename, mediaType
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let text = try container.decodeIfPresent(String.self, forKey: .text) {
            content = .text(text)
        } else if let bytes = try container.decodeIfPresent(Data.self, forKey: .raw) {
            content = .bytes(bytes)
        } else if let uri = try container.decodeIfPresent(String.self, forKey: .url) {
            content = .uri(uri)
        } else if container.contains(.data) {
            content = .data(try container.decode(StructuredValue.self, forKey: .data))
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Part must contain one of: text, raw, url, data"
                )
            )
        }

        metadata = try container.decodeIfPresent(A2AMetadata.self, forKey: .metadata)
        filename = try container.decodeIfPresent(String.self, forKey: .filename)
        mediaType = try container.decodeIfPresent(String.self, forKey: .mediaType)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch content {
        case .text(let value): try container.encode(value, forKey: .text)
        case .bytes(let value): try container.encode(value, forKey: .raw)
        case .uri(let value): try container.encode(value, forKey: .url)
        case .data(let value): try container.encode(value, forKey: .data)
        }

        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encodeIfPresent(filename, forKey: .filename)
        try container.encodeIfPresent(mediaType, forKey: .mediaType)
    }
}

// MARK: - ExpressibleByStringLiteral

extension Part: ExpressibleByStringLiteral {
    /// Makes a bare string literal usable wherever a part is expected, which is what lets the
    /// message builder take text without ceremony.
    public init(stringLiteral value: String) {
        self = .text(value)
    }
}

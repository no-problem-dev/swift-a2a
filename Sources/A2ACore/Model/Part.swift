import Foundation
import StructuredDataCore

/// メッセージ／アーティファクトを構成するコンテンツ片（A2A `Part`）。
///
/// v1.0 では判別子フィールド（旧 `type`/`kind`）を持たず、コンテンツ種別は
/// JSON のメンバ名（`text` / `raw` / `url` / `data`）で表されます。`filename`・
/// `mediaType`・`metadata` はコンテンツ種別と並列の任意フィールドです。
public struct Part: Sendable, Hashable {
    /// コンテンツ本体（oneof）。
    public enum Content: Sendable, Hashable {
        /// テキスト。
        case text(String)
        /// ファイルのバイト列（JSON では Base64 文字列、proto `raw`）。
        case bytes(Data)
        /// ファイルの参照 URI（proto `url`）。
        case uri(String)
        /// 任意の構造化データ（proto `data`、JSON の任意値）。
        case data(StructuredValue)
    }

    /// コンテンツ本体。
    public var content: Content
    /// このパートに付随するメタデータ。
    public var metadata: A2AMetadata?
    /// ファイル名（例 `document.pdf`）。
    public var filename: String?
    /// コンテンツの MIME タイプ（例 `text/plain`, `image/png`）。全種別で利用可能。
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
    /// テキストパートを作成。
    public static func text(_ text: String, metadata: A2AMetadata? = nil) -> Part {
        Part(content: .text(text), metadata: metadata)
    }

    /// バイト列を持つファイルパートを作成。
    public static func file(
        bytes: Data,
        filename: String? = nil,
        mediaType: String? = nil,
        metadata: A2AMetadata? = nil
    ) -> Part {
        Part(content: .bytes(bytes), metadata: metadata, filename: filename, mediaType: mediaType)
    }

    /// URI を持つファイルパートを作成。
    public static func file(
        uri: String,
        filename: String? = nil,
        mediaType: String? = nil,
        metadata: A2AMetadata? = nil
    ) -> Part {
        Part(content: .uri(uri), metadata: metadata, filename: filename, mediaType: mediaType)
    }

    /// 構造化データパートを作成。
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
    /// テキストパートならその文字列。
    public var text: String? {
        if case .text(let value) = content { return value }
        return nil
    }

    /// バイト列ファイルパートならそのデータ。
    public var bytes: Data? {
        if case .bytes(let value) = content { return value }
        return nil
    }

    /// URI ファイルパートならその URI。
    public var uri: String? {
        if case .uri(let value) = content { return value }
        return nil
    }

    /// データパートならその構造化値。
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
    /// 文字列リテラルからテキストパートを作成（ビルダー DSL 用）。
    public init(stringLiteral value: String) {
        self = .text(value)
    }
}

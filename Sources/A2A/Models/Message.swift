import Foundation

// MARK: - Message

/// A2Aメッセージ
///
/// エージェント間でやり取りされるメッセージです。
/// テキスト、ファイル、データの各パートを含むことができます。
public struct Message: Codable, Sendable, Equatable {
    /// メッセージの役割
    public let role: Role

    /// メッセージの各パート
    public let parts: [Part]

    /// メタデータ
    public let metadata: [String: AnyCodable]?

    public init(
        role: Role,
        parts: [Part],
        metadata: [String: AnyCodable]? = nil
    ) {
        self.role = role
        self.parts = parts
        self.metadata = metadata
    }
}

// MARK: - Role

/// メッセージの役割
public enum Role: String, Codable, Sendable, Equatable {
    /// ユーザー（リクエスター）
    case user
    /// エージェント（レスポンダー）
    case agent
}

// MARK: - Part

/// メッセージのパート（テキスト・ファイル・データ）
///
/// "type" キーでカスタム Codable を実装しています。
public enum Part: Sendable, Equatable {
    /// テキストパート
    case text(TextPart)
    /// ファイルパート
    case file(FilePart)
    /// データパート
    case data(DataPart)
}

extension Part: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            self = .text(try TextPart(from: decoder))
        case "file":
            self = .file(try FilePart(from: decoder))
        case "data":
            self = .data(try DataPart(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown part type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let part):
            try part.encode(to: encoder)
        case .file(let part):
            try part.encode(to: encoder)
        case .data(let part):
            try part.encode(to: encoder)
        }
    }
}

// MARK: - TextPart

/// テキストパート
public struct TextPart: Codable, Sendable, Equatable {
    /// パートタイプ（常に "text"）
    public let type: String

    /// テキスト内容
    public let text: String

    /// メタデータ
    public let metadata: [String: AnyCodable]?

    public init(text: String, metadata: [String: AnyCodable]? = nil) {
        self.type = "text"
        self.text = text
        self.metadata = metadata
    }
}

// MARK: - FilePart

/// ファイルパート
public struct FilePart: Codable, Sendable, Equatable {
    /// パートタイプ（常に "file"）
    public let type: String

    /// ファイル情報
    public let file: FileContent

    /// メタデータ
    public let metadata: [String: AnyCodable]?

    public init(file: FileContent, metadata: [String: AnyCodable]? = nil) {
        self.type = "file"
        self.file = file
        self.metadata = metadata
    }
}

// MARK: - FileContent

/// ファイルコンテンツ
public struct FileContent: Codable, Sendable, Equatable {
    /// ファイル名
    public let name: String?

    /// MIMEタイプ
    public let mimeType: String?

    /// ファイルデータ（Base64）
    public let bytes: String?

    /// ファイルURI
    public let uri: String?

    public init(
        name: String? = nil,
        mimeType: String? = nil,
        bytes: String? = nil,
        uri: String? = nil
    ) {
        self.name = name
        self.mimeType = mimeType
        self.bytes = bytes
        self.uri = uri
    }
}

// MARK: - DataPart

/// データパート
public struct DataPart: Codable, Sendable, Equatable {
    /// パートタイプ（常に "data"）
    public let type: String

    /// データ内容
    public let data: [String: AnyCodable]

    /// メタデータ
    public let metadata: [String: AnyCodable]?

    public init(data: [String: AnyCodable], metadata: [String: AnyCodable]? = nil) {
        self.type = "data"
        self.data = data
        self.metadata = metadata
    }
}

// MARK: - Convenience

extension Message {
    /// テキストメッセージを簡易作成
    public static func user(_ text: String) -> Message {
        Message(role: .user, parts: [.text(TextPart(text: text))])
    }

    /// エージェントのテキスト応答を簡易作成
    public static func agent(_ text: String) -> Message {
        Message(role: .agent, parts: [.text(TextPart(text: text))])
    }
}

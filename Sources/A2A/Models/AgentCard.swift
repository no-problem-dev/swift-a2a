import Foundation

// MARK: - AgentCard

/// A2Aエージェントのメタデータカード
///
/// `/.well-known/agent.json` で公開されるエージェント情報です。
/// エージェントの能力、スキル、認証方式などを記述します。
public struct AgentCard: Codable, Sendable, Equatable {
    /// エージェント名
    public let name: String

    /// エージェントの説明
    public let description: String?

    /// エージェントのURL
    public let url: String

    /// エージェントのプロバイダー情報
    public let provider: AgentProvider?

    /// エージェントのバージョン
    public let version: String?

    /// ドキュメントURL
    public let documentationUrl: String?

    /// エージェントの能力
    public let capabilities: AgentCapabilities?

    /// セキュリティスキーム
    public let securitySchemes: [String: SecurityScheme]?

    /// セキュリティ要件
    public let security: [[String: [String]]]?

    /// エージェントのスキル一覧
    public let skills: [AgentSkill]?

    /// デフォルトの入力モード
    public let defaultInputModes: [String]?

    /// デフォルトの出力モード
    public let defaultOutputModes: [String]?

    /// サポートするプロトコルバージョン
    public let supportsAuthenticatedExtendedCard: Bool?

    /// 拡張情報
    public let extensions: [AgentExtension]?

    public init(
        name: String,
        description: String? = nil,
        url: String,
        provider: AgentProvider? = nil,
        version: String? = nil,
        documentationUrl: String? = nil,
        capabilities: AgentCapabilities? = nil,
        securitySchemes: [String: SecurityScheme]? = nil,
        security: [[String: [String]]]? = nil,
        skills: [AgentSkill]? = nil,
        defaultInputModes: [String]? = nil,
        defaultOutputModes: [String]? = nil,
        supportsAuthenticatedExtendedCard: Bool? = nil,
        extensions: [AgentExtension]? = nil
    ) {
        self.name = name
        self.description = description
        self.url = url
        self.provider = provider
        self.version = version
        self.documentationUrl = documentationUrl
        self.capabilities = capabilities
        self.securitySchemes = securitySchemes
        self.security = security
        self.skills = skills
        self.defaultInputModes = defaultInputModes
        self.defaultOutputModes = defaultOutputModes
        self.supportsAuthenticatedExtendedCard = supportsAuthenticatedExtendedCard
        self.extensions = extensions
    }
}

// MARK: - AgentProvider

/// エージェントのプロバイダー情報
public struct AgentProvider: Codable, Sendable, Equatable {
    /// プロバイダー名
    public let organization: String

    /// プロバイダーURL
    public let url: String?

    public init(organization: String, url: String? = nil) {
        self.organization = organization
        self.url = url
    }
}

// MARK: - AgentCapabilities

/// エージェントの能力
public struct AgentCapabilities: Codable, Sendable, Equatable {
    /// ストリーミングをサポートするか
    public let streaming: Bool?

    /// プッシュ通知をサポートするか
    public let pushNotifications: Bool?

    /// 状態遷移通知をサポートするか
    public let stateTransitionHistory: Bool?

    public init(
        streaming: Bool? = nil,
        pushNotifications: Bool? = nil,
        stateTransitionHistory: Bool? = nil
    ) {
        self.streaming = streaming
        self.pushNotifications = pushNotifications
        self.stateTransitionHistory = stateTransitionHistory
    }
}

// MARK: - AgentSkill

/// エージェントのスキル定義
public struct AgentSkill: Codable, Sendable, Equatable {
    /// スキルID
    public let id: String

    /// スキル名
    public let name: String

    /// スキルの説明
    public let description: String?

    /// タグ
    public let tags: [String]?

    /// サポートする入力モード
    public let inputModes: [String]?

    /// サポートする出力モード
    public let outputModes: [String]?

    /// 入力例
    public let examples: [SkillExample]?

    public init(
        id: String,
        name: String,
        description: String? = nil,
        tags: [String]? = nil,
        inputModes: [String]? = nil,
        outputModes: [String]? = nil,
        examples: [SkillExample]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.tags = tags
        self.inputModes = inputModes
        self.outputModes = outputModes
        self.examples = examples
    }
}

// MARK: - SkillExample

/// スキルの入出力例
public struct SkillExample: Codable, Sendable, Equatable {
    /// 入力例
    public let input: String?

    /// 出力例
    public let output: String?

    public init(input: String? = nil, output: String? = nil) {
        self.input = input
        self.output = output
    }
}

// MARK: - AgentExtension

/// エージェントの拡張情報
public struct AgentExtension: Codable, Sendable, Equatable {
    /// 拡張URI
    public let uri: String

    /// 拡張の説明
    public let description: String?

    /// 必須かどうか
    public let required: Bool?

    /// 拡張パラメータ
    public let params: [String: AnyCodable]?

    public init(
        uri: String,
        description: String? = nil,
        required: Bool? = nil,
        params: [String: AnyCodable]? = nil
    ) {
        self.uri = uri
        self.description = description
        self.required = required
        self.params = params
    }
}

// MARK: - AgentCardSignature

/// エージェントカードの署名情報
public struct AgentCardSignature: Codable, Sendable, Equatable {
    /// 署名アルゴリズム
    public let algorithm: String

    /// 公開鍵ID
    public let keyId: String

    /// 署名値
    public let signature: String

    public init(algorithm: String, keyId: String, signature: String) {
        self.algorithm = algorithm
        self.keyId = keyId
        self.signature = signature
    }
}

// MARK: - AgentInterface

/// エージェントインターフェース定義
public struct AgentInterface: Codable, Sendable, Equatable {
    /// インターフェースタイプ
    public let type: String

    /// バージョン
    public let version: String?

    public init(type: String, version: String? = nil) {
        self.type = type
        self.version = version
    }
}

// MARK: - AgentCard

/// エージェントの自己記述マニフェスト（A2A `AgentCard`）。
///
/// 通常 `https://{host}/.well-known/agent-card.json` で公開される。
public struct AgentCard: Sendable, Hashable {
    /// 人間可読なエージェント名。
    public var name: String
    /// エージェントの説明。
    public var description: String
    /// 対応インターフェース一覧（順序付き。先頭が推奨）。
    public var supportedInterfaces: [AgentInterface]
    /// 提供元情報。
    public var provider: AgentProvider?
    /// エージェントのバージョン。
    public var version: String
    /// 追加ドキュメントの URL。
    public var documentationUrl: String?
    /// 対応ケイパビリティ。
    public var capabilities: AgentCapabilities
    /// セキュリティスキーム定義（名前 → スキーム）。
    public var securitySchemes: [String: SecurityScheme]?
    /// セキュリティ要件（OpenAPI 慣習のフラット形）。
    public var security: [SecurityRequirement]
    /// 全スキル共通の既定入力モード（メディアタイプ）。
    public var defaultInputModes: [String]
    /// 既定出力モード（メディアタイプ）。
    public var defaultOutputModes: [String]
    /// エージェントのスキル一覧。
    public var skills: [AgentSkill]
    /// このカードに対する JWS 署名。
    public var signatures: [AgentCardSignature]
    /// エージェントアイコンの URL。
    public var iconUrl: String?

    public init(
        name: String,
        description: String,
        supportedInterfaces: [AgentInterface],
        version: String,
        capabilities: AgentCapabilities,
        provider: AgentProvider? = nil,
        documentationUrl: String? = nil,
        securitySchemes: [String: SecurityScheme]? = nil,
        security: [SecurityRequirement] = [],
        defaultInputModes: [String] = [],
        defaultOutputModes: [String] = [],
        skills: [AgentSkill] = [],
        signatures: [AgentCardSignature] = [],
        iconUrl: String? = nil
    ) {
        self.name = name
        self.description = description
        self.supportedInterfaces = supportedInterfaces
        self.version = version
        self.capabilities = capabilities
        self.provider = provider
        self.documentationUrl = documentationUrl
        self.securitySchemes = securitySchemes
        self.security = security
        self.defaultInputModes = defaultInputModes
        self.defaultOutputModes = defaultOutputModes
        self.skills = skills
        self.signatures = signatures
        self.iconUrl = iconUrl
    }
}

extension AgentCard: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, description, supportedInterfaces, provider, version, documentationUrl,
            capabilities, securitySchemes, security, securityRequirements,
            defaultInputModes, defaultOutputModes, skills, signatures, iconUrl
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeString(forKey: .name)
        description = try container.decodeString(forKey: .description)
        supportedInterfaces = try container.decodeArray(forKey: .supportedInterfaces)
        provider = try container.decodeIfPresent(AgentProvider.self, forKey: .provider)
        version = try container.decodeString(forKey: .version)
        documentationUrl = try container.decodeIfPresent(String.self, forKey: .documentationUrl)
        capabilities = try container.decodeIfPresent(AgentCapabilities.self, forKey: .capabilities) ?? AgentCapabilities()
        securitySchemes = try container.decodeIfPresent([String: SecurityScheme].self, forKey: .securitySchemes)
        // proto json_name は securityRequirements だが docs/エコシステムは security。両方受理。
        if container.contains(.security) {
            security = try container.decodeArray(forKey: .security)
        } else {
            security = try container.decodeArray(forKey: .securityRequirements)
        }
        defaultInputModes = try container.decodeArray(forKey: .defaultInputModes)
        defaultOutputModes = try container.decodeArray(forKey: .defaultOutputModes)
        skills = try container.decodeArray(forKey: .skills)
        signatures = try container.decodeArray(forKey: .signatures)
        iconUrl = try container.decodeIfPresent(String.self, forKey: .iconUrl)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfNonEmpty(name, forKey: .name)
        try container.encodeIfNonEmpty(description, forKey: .description)
        try container.encodeIfNonEmpty(supportedInterfaces, forKey: .supportedInterfaces)
        try container.encodeIfPresent(provider, forKey: .provider)
        try container.encodeIfNonEmpty(version, forKey: .version)
        try container.encodeIfPresent(documentationUrl, forKey: .documentationUrl)
        try container.encode(capabilities, forKey: .capabilities)
        try container.encodeIfPresent(securitySchemes, forKey: .securitySchemes)
        try container.encodeIfNonEmpty(security, forKey: .security)
        try container.encodeIfNonEmpty(defaultInputModes, forKey: .defaultInputModes)
        try container.encodeIfNonEmpty(defaultOutputModes, forKey: .defaultOutputModes)
        try container.encodeIfNonEmpty(skills, forKey: .skills)
        try container.encodeIfNonEmpty(signatures, forKey: .signatures)
        try container.encodeIfPresent(iconUrl, forKey: .iconUrl)
    }
}

// MARK: - AgentInterface

/// エージェントの対応インターフェース宣言（A2A `AgentInterface`）。
public struct AgentInterface: Sendable, Hashable {
    /// このインターフェースの URL（本番は絶対 HTTPS）。
    public var url: String
    /// プロトコルバインディング（`JSONRPC` / `GRPC` / `HTTP+JSON` または URI）。
    public var protocolBinding: String
    /// マルチテナント用のルーティング識別子。
    public var tenant: String?
    /// このインターフェースが公開する A2A プロトコルバージョン（例 `1.0`）。
    public var protocolVersion: String

    public init(url: String, protocolBinding: String, protocolVersion: String = "", tenant: String? = nil) {
        self.url = url
        self.protocolBinding = protocolBinding
        self.protocolVersion = protocolVersion
        self.tenant = tenant
    }
}

extension AgentInterface: Codable {
    private enum CodingKeys: String, CodingKey { case url, protocolBinding, tenant, protocolVersion }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decodeString(forKey: .url)
        protocolBinding = try container.decodeString(forKey: .protocolBinding)
        tenant = try container.decodeIfPresent(String.self, forKey: .tenant)
        protocolVersion = try container.decodeString(forKey: .protocolVersion)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfNonEmpty(url, forKey: .url)
        try container.encodeIfNonEmpty(protocolBinding, forKey: .protocolBinding)
        try container.encodeIfPresent(tenant, forKey: .tenant)
        try container.encodeIfNonEmpty(protocolVersion, forKey: .protocolVersion)
    }
}

// MARK: - AgentProvider

/// エージェントの提供元（A2A `AgentProvider`）。
public struct AgentProvider: Sendable, Hashable {
    /// 提供元 Web サイト等の URL。
    public var url: String
    /// 提供元組織名。
    public var organization: String

    public init(url: String, organization: String) {
        self.url = url
        self.organization = organization
    }
}

extension AgentProvider: Codable {
    private enum CodingKeys: String, CodingKey { case url, organization }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decodeString(forKey: .url)
        organization = try container.decodeString(forKey: .organization)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfNonEmpty(url, forKey: .url)
        try container.encodeIfNonEmpty(organization, forKey: .organization)
    }
}

// MARK: - AgentCapabilities

/// エージェントの任意ケイパビリティ（A2A `AgentCapabilities`）。
public struct AgentCapabilities: Sendable, Hashable {
    /// ストリーミング応答に対応するか。
    public var streaming: Bool?
    /// 非同期タスク更新のプッシュ通知に対応するか。
    public var pushNotifications: Bool?
    /// 対応する拡張一覧。
    public var extensions: [AgentExtension]
    /// 認証時に拡張 Agent Card を提供できるか。
    public var extendedAgentCard: Bool?

    public init(
        streaming: Bool? = nil,
        pushNotifications: Bool? = nil,
        extensions: [AgentExtension] = [],
        extendedAgentCard: Bool? = nil
    ) {
        self.streaming = streaming
        self.pushNotifications = pushNotifications
        self.extensions = extensions
        self.extendedAgentCard = extendedAgentCard
    }
}

extension AgentCapabilities: Codable {
    private enum CodingKeys: String, CodingKey {
        case streaming, pushNotifications, extensions, extendedAgentCard
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streaming = try container.decodeIfPresent(Bool.self, forKey: .streaming)
        pushNotifications = try container.decodeIfPresent(Bool.self, forKey: .pushNotifications)
        extensions = try container.decodeArray(forKey: .extensions)
        extendedAgentCard = try container.decodeIfPresent(Bool.self, forKey: .extendedAgentCard)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // optional bool は presence-tracked。設定されていれば false でも出力。
        try container.encodeIfPresent(streaming, forKey: .streaming)
        try container.encodeIfPresent(pushNotifications, forKey: .pushNotifications)
        try container.encodeIfNonEmpty(extensions, forKey: .extensions)
        try container.encodeIfPresent(extendedAgentCard, forKey: .extendedAgentCard)
    }
}

// MARK: - AgentExtension

/// エージェントが対応するプロトコル拡張の宣言（A2A `AgentExtension`）。
public struct AgentExtension: Sendable, Hashable {
    /// 拡張を一意に識別する URI。
    public var uri: String
    /// この拡張の利用方法の説明。
    public var description: String?
    /// `true` ならクライアントはこの拡張を理解・遵守する必要がある。
    public var required: Bool
    /// 拡張固有の構成パラメータ。
    public var params: A2AMetadata?

    public init(uri: String, description: String? = nil, required: Bool = false, params: A2AMetadata? = nil) {
        self.uri = uri
        self.description = description
        self.required = required
        self.params = params
    }
}

extension AgentExtension: Codable {
    private enum CodingKeys: String, CodingKey { case uri, description, required, params }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uri = try container.decodeString(forKey: .uri)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        required = try container.decodeBool(forKey: .required)
        params = try container.decodeIfPresent(A2AMetadata.self, forKey: .params)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfNonEmpty(uri, forKey: .uri)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfTrue(required, forKey: .required)
        try container.encodeIfPresent(params, forKey: .params)
    }
}

// MARK: - AgentSkill

/// エージェントが実行できる機能（A2A `AgentSkill`）。
public struct AgentSkill: Sendable, Hashable {
    /// スキルの一意識別子。
    public var id: String
    /// スキル名。
    public var name: String
    /// スキルの説明。
    public var description: String
    /// スキルの能力を表すキーワード。
    public var tags: [String]
    /// このスキルが扱える例（プロンプト等）。
    public var examples: [String]
    /// エージェント既定を上書きする入力モード。
    public var inputModes: [String]
    /// エージェント既定を上書きする出力モード。
    public var outputModes: [String]
    /// このスキルに必要なセキュリティ要件。
    public var securityRequirements: [SecurityRequirement]

    public init(
        id: String,
        name: String,
        description: String,
        tags: [String],
        examples: [String] = [],
        inputModes: [String] = [],
        outputModes: [String] = [],
        securityRequirements: [SecurityRequirement] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.tags = tags
        self.examples = examples
        self.inputModes = inputModes
        self.outputModes = outputModes
        self.securityRequirements = securityRequirements
    }
}

extension AgentSkill: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, description, tags, examples, inputModes, outputModes, securityRequirements
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeString(forKey: .id)
        name = try container.decodeString(forKey: .name)
        description = try container.decodeString(forKey: .description)
        tags = try container.decodeArray(forKey: .tags)
        examples = try container.decodeArray(forKey: .examples)
        inputModes = try container.decodeArray(forKey: .inputModes)
        outputModes = try container.decodeArray(forKey: .outputModes)
        securityRequirements = try container.decodeArray(forKey: .securityRequirements)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfNonEmpty(id, forKey: .id)
        try container.encodeIfNonEmpty(name, forKey: .name)
        try container.encodeIfNonEmpty(description, forKey: .description)
        try container.encodeIfNonEmpty(tags, forKey: .tags)
        try container.encodeIfNonEmpty(examples, forKey: .examples)
        try container.encodeIfNonEmpty(inputModes, forKey: .inputModes)
        try container.encodeIfNonEmpty(outputModes, forKey: .outputModes)
        try container.encodeIfNonEmpty(securityRequirements, forKey: .securityRequirements)
    }
}

// MARK: - AgentCardSignature

/// Agent Card の JWS 署名（A2A `AgentCardSignature`、RFC 7515）。
public struct AgentCardSignature: Sendable, Hashable {
    /// 保護 JWS ヘッダ（base64url エンコードの JSON）。
    public var `protected`: String
    /// 計算された署名（base64url）。
    public var signature: String
    /// 非保護 JWS ヘッダ値。
    public var header: A2AMetadata?

    public init(protected: String, signature: String, header: A2AMetadata? = nil) {
        self.protected = `protected`
        self.signature = signature
        self.header = header
    }
}

extension AgentCardSignature: Codable {
    private enum CodingKeys: String, CodingKey { case `protected`, signature, header }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        `protected` = try container.decodeString(forKey: .protected)
        signature = try container.decodeString(forKey: .signature)
        header = try container.decodeIfPresent(A2AMetadata.self, forKey: .header)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfNonEmpty(`protected`, forKey: .protected)
        try container.encodeIfNonEmpty(signature, forKey: .signature)
        try container.encodeIfPresent(header, forKey: .header)
    }
}

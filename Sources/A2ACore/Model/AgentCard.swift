// MARK: - AgentCard

/// An agent's self-description: who it is, what it can do, how to reach it and how to authenticate.
///
/// Served at the well-known path, so a client can discover an agent knowing only its host. An
/// extended card carrying more detail may be available to authenticated callers.
public struct AgentCard: Sendable, Hashable {
    /// The agent's name, for people to read.
    public var name: String
    /// What the agent does, for people to read.
    public var description: String
    /// The endpoints this agent answers on, most preferred first. A client that speaks more than
    /// one binding should take the first entry it recognizes.
    public var supportedInterfaces: [AgentInterface]
    /// Who publishes the agent.
    public var provider: AgentProvider?
    /// The agent's own version, unrelated to the protocol version.
    public var version: String
    /// Where to read more about the agent.
    public var documentationUrl: String?
    /// The optional protocol features this agent supports.
    public var capabilities: AgentCapabilities
    /// The authentication schemes this agent accepts, keyed by the name `security` refers to.
    public var securitySchemes: [String: SecurityScheme]?
    /// Which schemes a caller must satisfy, in the flat OpenAPI shape — see ``SecurityRequirement``
    /// for why this diverges from the Protocol Buffer definition.
    public var security: [SecurityRequirement]
    /// Media types every skill accepts, unless a skill overrides them.
    public var defaultInputModes: [String]
    /// Media types every skill produces, unless a skill overrides them.
    public var defaultOutputModes: [String]
    /// What the agent can be asked to do.
    public var skills: [AgentSkill]
    /// JWS signatures over this card. Nothing here verifies them.
    public var signatures: [AgentCardSignature]
    /// An icon for the agent.
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
        // The Protocol Buffer json_name is `securityRequirements`, but the specification's own
        // examples and the wider ecosystem write `security`. Both are accepted on the way in;
        // encoding always writes `security`.
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

/// One endpoint an agent answers on, and the binding it speaks there.
public struct AgentInterface: Sendable, Hashable {
    /// Where to send requests. Absolute HTTPS in production.
    public var url: String
    /// Which binding this endpoint speaks: `JSONRPC`, `GRPC`, `HTTP+JSON`, or a URI naming another.
    /// This package implements the first and third; `GRPC` endpoints cannot be reached from here.
    public var protocolBinding: String
    /// An opaque routing identifier for multi-tenant deployments, echoed back on requests.
    public var tenant: String?
    /// The major protocol version this endpoint speaks, such as `1.0` — coarser than the spec
    /// revision sent in the version header.
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

/// Who publishes an agent.
public struct AgentProvider: Sendable, Hashable {
    /// The provider's website.
    public var url: String
    /// The organization's name.
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

/// The optional protocol features an agent supports.
///
/// Each flag is three-valued: `true`, `false`, and absent. The server framework here treats
/// anything other than an explicit `true` as unsupported, so leaving `streaming` unset makes
/// streaming requests fail.
public struct AgentCapabilities: Sendable, Hashable {
    /// Whether the agent can stream updates rather than only answering once.
    public var streaming: Bool?
    /// Whether the agent can push task updates to a webhook.
    public var pushNotifications: Bool?
    /// The protocol extensions the agent supports.
    public var extensions: [AgentExtension]
    /// Whether an authenticated caller can fetch a fuller card.
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
        // Presence is meaningful for these flags, so an explicit `false` is written out — unlike
        // the proto3 default-value rule applied to the non-optional fields.
        try container.encodeIfPresent(streaming, forKey: .streaming)
        try container.encodeIfPresent(pushNotifications, forKey: .pushNotifications)
        try container.encodeIfNonEmpty(extensions, forKey: .extensions)
        try container.encodeIfPresent(extendedAgentCard, forKey: .extendedAgentCard)
    }
}

// MARK: - AgentExtension

/// A protocol extension an agent supports.
public struct AgentExtension: Sendable, Hashable {
    /// Identifies the extension. Clients match on this exact string.
    public var uri: String
    /// How to use the extension, for people to read.
    public var description: String?
    /// Whether a client must understand this extension to interoperate at all. Nothing here
    /// enforces it — a client that ignores a required extension is on its own.
    public var required: Bool
    /// Configuration the extension defines.
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

/// Something an agent can be asked to do.
///
/// Skills are advertisement, not routing: there is no field on a request that selects one. A
/// client picks an agent by its skills and then says what it wants in a message.
public struct AgentSkill: Sendable, Hashable {
    /// Identifies the skill within the card.
    public var id: String
    /// The skill's name, for people to read.
    public var name: String
    /// What the skill does, for people to read.
    public var description: String
    /// Keywords for discovery.
    public var tags: [String]
    /// Sample prompts this skill handles.
    public var examples: [String]
    /// Media types this skill accepts, replacing the card's defaults when non-empty.
    public var inputModes: [String]
    /// Media types this skill produces, replacing the card's defaults when non-empty.
    public var outputModes: [String]
    /// Authentication this skill requires beyond the card's own requirements.
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

/// A JWS signature over an agent card, in the detached form of RFC 7515.
///
/// Nothing in this package produces or verifies these — the fields are carried through so a caller
/// can hand them to a JWS implementation.
public struct AgentCardSignature: Sendable, Hashable {
    /// The protected JWS header: base64url-encoded JSON, covered by the signature.
    public var `protected`: String
    /// The signature itself, base64url-encoded.
    public var signature: String
    /// Unprotected header values, which the signature does not cover.
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

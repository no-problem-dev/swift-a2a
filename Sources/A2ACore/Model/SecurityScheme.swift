// MARK: - SecurityScheme

/// How callers authenticate to an agent.
///
/// Like ``Part``, this carries no discriminator: the kind is the JSON member name
/// (`apiKeySecurityScheme`, `httpAuthSecurityScheme`, …). Decoding rejects an object naming none
/// of the five, so a scheme added in a later revision fails rather than degrading.
public enum SecurityScheme: Sendable, Hashable {
    case apiKey(APIKeySecurityScheme)
    case httpAuth(HTTPAuthSecurityScheme)
    case oauth2(OAuth2SecurityScheme)
    case openIdConnect(OpenIdConnectSecurityScheme)
    case mutualTLS(MutualTLSSecurityScheme)
}

extension SecurityScheme: Codable {
    private enum CodingKeys: String, CodingKey {
        case apiKeySecurityScheme, httpAuthSecurityScheme, oauth2SecurityScheme,
            openIdConnectSecurityScheme, mtlsSecurityScheme
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.apiKeySecurityScheme) {
            self = .apiKey(try container.decode(APIKeySecurityScheme.self, forKey: .apiKeySecurityScheme))
        } else if container.contains(.httpAuthSecurityScheme) {
            self = .httpAuth(try container.decode(HTTPAuthSecurityScheme.self, forKey: .httpAuthSecurityScheme))
        } else if container.contains(.oauth2SecurityScheme) {
            self = .oauth2(try container.decode(OAuth2SecurityScheme.self, forKey: .oauth2SecurityScheme))
        } else if container.contains(.openIdConnectSecurityScheme) {
            self = .openIdConnect(try container.decode(OpenIdConnectSecurityScheme.self, forKey: .openIdConnectSecurityScheme))
        } else if container.contains(.mtlsSecurityScheme) {
            self = .mutualTLS(try container.decode(MutualTLSSecurityScheme.self, forKey: .mtlsSecurityScheme))
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown SecurityScheme variant"
                )
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .apiKey(let value): try container.encode(value, forKey: .apiKeySecurityScheme)
        case .httpAuth(let value): try container.encode(value, forKey: .httpAuthSecurityScheme)
        case .oauth2(let value): try container.encode(value, forKey: .oauth2SecurityScheme)
        case .openIdConnect(let value): try container.encode(value, forKey: .openIdConnectSecurityScheme)
        case .mutualTLS(let value): try container.encode(value, forKey: .mtlsSecurityScheme)
        }
    }
}

// MARK: - Scheme variants

/// A shared key the caller sends on every request.
public struct APIKeySecurityScheme: Codable, Sendable, Hashable {
    /// Where the key goes.
    public enum Location: String, Sendable, Codable, Hashable {
        case query, header, cookie
    }

    public var location: Location
    public var name: String
    public var description: String?

    public init(location: Location, name: String, description: String? = nil) {
        self.location = location
        self.name = name
        self.description = description
    }
}

/// Standard HTTP authentication, named by its IANA-registered scheme such as `Bearer` or `Basic`.
public struct HTTPAuthSecurityScheme: Codable, Sendable, Hashable {
    public var scheme: String
    public var bearerFormat: String?
    public var description: String?

    public init(scheme: String, bearerFormat: String? = nil, description: String? = nil) {
        self.scheme = scheme
        self.bearerFormat = bearerFormat
        self.description = description
    }
}

/// OAuth 2.0, described by the flows the agent accepts.
public struct OAuth2SecurityScheme: Codable, Sendable, Hashable {
    public var flows: OAuthFlows
    public var oauth2MetadataUrl: String?
    public var description: String?

    public init(flows: OAuthFlows, oauth2MetadataUrl: String? = nil, description: String? = nil) {
        self.flows = flows
        self.oauth2MetadataUrl = oauth2MetadataUrl
        self.description = description
    }
}

/// OpenID Connect, described by its discovery document.
public struct OpenIdConnectSecurityScheme: Codable, Sendable, Hashable {
    public var openIdConnectUrl: String
    public var description: String?

    public init(openIdConnectUrl: String, description: String? = nil) {
        self.openIdConnectUrl = openIdConnectUrl
        self.description = description
    }
}

/// Mutual TLS: the client certificate is the credential, so the scheme carries no parameters.
public struct MutualTLSSecurityScheme: Codable, Sendable, Hashable {
    public var description: String?

    public init(description: String? = nil) {
        self.description = description
    }
}

// MARK: - OAuthFlows

/// The OAuth 2.0 flows an agent accepts.
///
/// A deliberate divergence: the Protocol Buffer definition makes this a oneof, so exactly one flow
/// at a time. Real cards follow the OpenAPI convention of listing several, so every flow is an
/// independent optional field here. A card with two flows round-trips through this type intact,
/// which a faithful oneof would not allow.
public struct OAuthFlows: Codable, Sendable, Hashable {
    public var authorizationCode: AuthorizationCodeOAuthFlow?
    public var clientCredentials: ClientCredentialsOAuthFlow?
    public var implicit: ImplicitOAuthFlow?
    public var password: PasswordOAuthFlow?
    public var deviceCode: DeviceCodeOAuthFlow?

    public init(
        authorizationCode: AuthorizationCodeOAuthFlow? = nil,
        clientCredentials: ClientCredentialsOAuthFlow? = nil,
        implicit: ImplicitOAuthFlow? = nil,
        password: PasswordOAuthFlow? = nil,
        deviceCode: DeviceCodeOAuthFlow? = nil
    ) {
        self.authorizationCode = authorizationCode
        self.clientCredentials = clientCredentials
        self.implicit = implicit
        self.password = password
        self.deviceCode = deviceCode
    }
}

/// The authorization code flow, optionally requiring PKCE.
public struct AuthorizationCodeOAuthFlow: Codable, Sendable, Hashable {
    public var authorizationUrl: String
    public var tokenUrl: String
    public var refreshUrl: String?
    public var scopes: [String: String]
    public var pkceRequired: Bool

    public init(
        authorizationUrl: String,
        tokenUrl: String,
        refreshUrl: String? = nil,
        scopes: [String: String] = [:],
        pkceRequired: Bool = false
    ) {
        self.authorizationUrl = authorizationUrl
        self.tokenUrl = tokenUrl
        self.refreshUrl = refreshUrl
        self.scopes = scopes
        self.pkceRequired = pkceRequired
    }

    private enum CodingKeys: String, CodingKey {
        case authorizationUrl, tokenUrl, refreshUrl, scopes, pkceRequired
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        authorizationUrl = try container.decode(String.self, forKey: .authorizationUrl)
        tokenUrl = try container.decode(String.self, forKey: .tokenUrl)
        refreshUrl = try container.decodeIfPresent(String.self, forKey: .refreshUrl)
        scopes = try container.decodeIfPresent([String: String].self, forKey: .scopes) ?? [:]
        pkceRequired = try container.decodeBool(forKey: .pkceRequired)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(authorizationUrl, forKey: .authorizationUrl)
        try container.encode(tokenUrl, forKey: .tokenUrl)
        try container.encodeIfPresent(refreshUrl, forKey: .refreshUrl)
        if !scopes.isEmpty { try container.encode(scopes, forKey: .scopes) }
        try container.encodeIfTrue(pkceRequired, forKey: .pkceRequired)
    }
}

/// The client credentials flow, for machine-to-machine calls with no end user.
public struct ClientCredentialsOAuthFlow: Codable, Sendable, Hashable {
    public var tokenUrl: String
    public var refreshUrl: String?
    public var scopes: [String: String]

    public init(tokenUrl: String, refreshUrl: String? = nil, scopes: [String: String] = [:]) {
        self.tokenUrl = tokenUrl
        self.refreshUrl = refreshUrl
        self.scopes = scopes
    }

    private enum CodingKeys: String, CodingKey { case tokenUrl, refreshUrl, scopes }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tokenUrl = try container.decode(String.self, forKey: .tokenUrl)
        refreshUrl = try container.decodeIfPresent(String.self, forKey: .refreshUrl)
        scopes = try container.decodeIfPresent([String: String].self, forKey: .scopes) ?? [:]
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tokenUrl, forKey: .tokenUrl)
        try container.encodeIfPresent(refreshUrl, forKey: .refreshUrl)
        if !scopes.isEmpty { try container.encode(scopes, forKey: .scopes) }
    }
}

/// The implicit flow. Discouraged by current OAuth guidance; present for cards that still use it.
public struct ImplicitOAuthFlow: Codable, Sendable, Hashable {
    public var authorizationUrl: String?
    public var refreshUrl: String?
    public var scopes: [String: String]

    public init(authorizationUrl: String? = nil, refreshUrl: String? = nil, scopes: [String: String] = [:]) {
        self.authorizationUrl = authorizationUrl
        self.refreshUrl = refreshUrl
        self.scopes = scopes
    }

    private enum CodingKeys: String, CodingKey { case authorizationUrl, refreshUrl, scopes }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        authorizationUrl = try container.decodeIfPresent(String.self, forKey: .authorizationUrl)
        refreshUrl = try container.decodeIfPresent(String.self, forKey: .refreshUrl)
        scopes = try container.decodeIfPresent([String: String].self, forKey: .scopes) ?? [:]
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(authorizationUrl, forKey: .authorizationUrl)
        try container.encodeIfPresent(refreshUrl, forKey: .refreshUrl)
        if !scopes.isEmpty { try container.encode(scopes, forKey: .scopes) }
    }
}

/// The resource owner password flow. Discouraged by current OAuth guidance; present for cards
/// that still use it.
public struct PasswordOAuthFlow: Codable, Sendable, Hashable {
    public var tokenUrl: String?
    public var refreshUrl: String?
    public var scopes: [String: String]

    public init(tokenUrl: String? = nil, refreshUrl: String? = nil, scopes: [String: String] = [:]) {
        self.tokenUrl = tokenUrl
        self.refreshUrl = refreshUrl
        self.scopes = scopes
    }

    private enum CodingKeys: String, CodingKey { case tokenUrl, refreshUrl, scopes }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tokenUrl = try container.decodeIfPresent(String.self, forKey: .tokenUrl)
        refreshUrl = try container.decodeIfPresent(String.self, forKey: .refreshUrl)
        scopes = try container.decodeIfPresent([String: String].self, forKey: .scopes) ?? [:]
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(tokenUrl, forKey: .tokenUrl)
        try container.encodeIfPresent(refreshUrl, forKey: .refreshUrl)
        if !scopes.isEmpty { try container.encode(scopes, forKey: .scopes) }
    }
}

/// The device authorization flow of RFC 8628, for inputs too limited to host a browser.
public struct DeviceCodeOAuthFlow: Codable, Sendable, Hashable {
    public var deviceAuthorizationUrl: String
    public var tokenUrl: String
    public var refreshUrl: String?
    public var scopes: [String: String]

    public init(
        deviceAuthorizationUrl: String,
        tokenUrl: String,
        refreshUrl: String? = nil,
        scopes: [String: String] = [:]
    ) {
        self.deviceAuthorizationUrl = deviceAuthorizationUrl
        self.tokenUrl = tokenUrl
        self.refreshUrl = refreshUrl
        self.scopes = scopes
    }

    private enum CodingKeys: String, CodingKey { case deviceAuthorizationUrl, tokenUrl, refreshUrl, scopes }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceAuthorizationUrl = try container.decode(String.self, forKey: .deviceAuthorizationUrl)
        tokenUrl = try container.decode(String.self, forKey: .tokenUrl)
        refreshUrl = try container.decodeIfPresent(String.self, forKey: .refreshUrl)
        scopes = try container.decodeIfPresent([String: String].self, forKey: .scopes) ?? [:]
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(deviceAuthorizationUrl, forKey: .deviceAuthorizationUrl)
        try container.encode(tokenUrl, forKey: .tokenUrl)
        try container.encodeIfPresent(refreshUrl, forKey: .refreshUrl)
        if !scopes.isEmpty { try container.encode(scopes, forKey: .scopes) }
    }
}

// MARK: - SecurityRequirement

/// One alternative set of credentials a caller may present: scheme name to required scopes.
///
/// Within a requirement every scheme listed must be satisfied; across the array in
/// ``AgentCard/security``, any one requirement suffices.
///
/// A deliberate divergence from the Protocol Buffer definition, which types this as
/// `map<string, StringList>` and therefore serializes as `{"scheme": {"list": ["scope"]}}`. The
/// specification's own examples and every card observed in the wild use the flat OpenAPI shape
/// `{"scheme": ["scope"]}`, so that is what is read and written here. A card following the proto
/// shape literally will fail to decode.
public typealias SecurityRequirement = [String: [String]]

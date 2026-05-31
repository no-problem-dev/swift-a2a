// MARK: - SecurityScheme

/// エージェントのエンドポイントを保護するセキュリティスキーム（A2A `SecurityScheme`、oneof）。
///
/// v1.0 ProtoJSON では判別子フィールドを持たず、JSON のメンバ名
/// （`apiKeySecurityScheme` 等）で種別が表されます（§8.5 のサンプルに準拠）。
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

/// API キー認証（`APIKeySecurityScheme`）。
public struct APIKeySecurityScheme: Codable, Sendable, Hashable {
    /// API キーの配置場所。
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

/// HTTP 認証（`HTTPAuthSecurityScheme`）。`scheme` は IANA 登録の自由文字列（例 `Bearer`）。
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

/// OAuth 2.0 認証（`OAuth2SecurityScheme`）。
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

/// OpenID Connect 認証（`OpenIdConnectSecurityScheme`）。
public struct OpenIdConnectSecurityScheme: Codable, Sendable, Hashable {
    public var openIdConnectUrl: String
    public var description: String?

    public init(openIdConnectUrl: String, description: String? = nil) {
        self.openIdConnectUrl = openIdConnectUrl
        self.description = description
    }
}

/// 相互 TLS 認証（`MutualTlsSecurityScheme`）。
public struct MutualTLSSecurityScheme: Codable, Sendable, Hashable {
    public var description: String?

    public init(description: String? = nil) {
        self.description = description
    }
}

// MARK: - OAuthFlows

/// 対応する OAuth 2.0 フロー群（A2A `OAuthFlows`）。
///
/// proto 上は oneof（同時に1フロー）ですが、現実のカードが複数フローを併記する
/// OpenAPI 慣習にも耐えられるよう、各フローを任意フィールドとして保持します。
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

/// Authorization Code フロー。
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

/// Client Credentials フロー。
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

/// Implicit フロー（非推奨）。
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

/// Password フロー（非推奨）。
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

/// Device Code フロー（RFC 8628）。
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

/// セキュリティ要件: スキーム名 → 必要スコープ一覧。
///
/// 注: proto は `map<string, StringList>`（`{"scheme":{"list":[...]}}`）と定義しますが、
/// 仕様書 §8.5 のサンプルおよび実エコシステムは OpenAPI 慣習のフラット形
/// （`{"scheme":["scope"]}`）を用いるため、相互運用性を優先しフラット形を採用します。
public typealias SecurityRequirement = [String: [String]]

import Foundation

// MARK: - SecurityScheme

/// セキュリティスキーム定義
///
/// OpenAPI互換のセキュリティスキーム定義です。
public enum SecurityScheme: Sendable, Equatable {
    /// APIキー認証
    case apiKey(APIKeyScheme)
    /// HTTP認証（Basic/Bearer等）
    case http(HTTPAuthScheme)
    /// OAuth 2.0認証
    case oauth2(OAuth2Scheme)
    /// OpenID Connect認証
    case openIdConnect(OpenIdConnectScheme)
}

extension SecurityScheme: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "apiKey":
            self = .apiKey(try APIKeyScheme(from: decoder))
        case "http":
            self = .http(try HTTPAuthScheme(from: decoder))
        case "oauth2":
            self = .oauth2(try OAuth2Scheme(from: decoder))
        case "openIdConnect":
            self = .openIdConnect(try OpenIdConnectScheme(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown security scheme type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .apiKey(let scheme):
            try scheme.encode(to: encoder)
        case .http(let scheme):
            try scheme.encode(to: encoder)
        case .oauth2(let scheme):
            try scheme.encode(to: encoder)
        case .openIdConnect(let scheme):
            try scheme.encode(to: encoder)
        }
    }
}

// MARK: - APIKeyScheme

/// APIキー認証スキーム
public struct APIKeyScheme: Codable, Sendable, Equatable {
    public let type: String
    public let name: String
    public let `in`: String
    public let description: String?

    public init(name: String, in location: String, description: String? = nil) {
        self.type = "apiKey"
        self.name = name
        self.in = location
        self.description = description
    }
}

// MARK: - HTTPAuthScheme

/// HTTP認証スキーム
public struct HTTPAuthScheme: Codable, Sendable, Equatable {
    public let type: String
    public let scheme: String
    public let bearerFormat: String?
    public let description: String?

    public init(scheme: String, bearerFormat: String? = nil, description: String? = nil) {
        self.type = "http"
        self.scheme = scheme
        self.bearerFormat = bearerFormat
        self.description = description
    }
}

// MARK: - OAuth2Scheme

/// OAuth 2.0認証スキーム
public struct OAuth2Scheme: Codable, Sendable, Equatable {
    public let type: String
    public let flows: OAuthFlows
    public let description: String?

    public init(flows: OAuthFlows, description: String? = nil) {
        self.type = "oauth2"
        self.flows = flows
        self.description = description
    }
}

// MARK: - OAuthFlows

/// OAuth 2.0フロー定義
public struct OAuthFlows: Codable, Sendable, Equatable {
    public let authorizationCode: OAuthFlow?
    public let clientCredentials: OAuthFlow?
    public let implicit: OAuthFlow?
    public let password: OAuthFlow?

    public init(
        authorizationCode: OAuthFlow? = nil,
        clientCredentials: OAuthFlow? = nil,
        implicit: OAuthFlow? = nil,
        password: OAuthFlow? = nil
    ) {
        self.authorizationCode = authorizationCode
        self.clientCredentials = clientCredentials
        self.implicit = implicit
        self.password = password
    }
}

// MARK: - OAuthFlow

/// OAuth 2.0フロー詳細
public struct OAuthFlow: Codable, Sendable, Equatable {
    public let authorizationUrl: String?
    public let tokenUrl: String?
    public let refreshUrl: String?
    public let scopes: [String: String]?

    public init(
        authorizationUrl: String? = nil,
        tokenUrl: String? = nil,
        refreshUrl: String? = nil,
        scopes: [String: String]? = nil
    ) {
        self.authorizationUrl = authorizationUrl
        self.tokenUrl = tokenUrl
        self.refreshUrl = refreshUrl
        self.scopes = scopes
    }
}

// MARK: - OpenIdConnectScheme

/// OpenID Connect認証スキーム
public struct OpenIdConnectScheme: Codable, Sendable, Equatable {
    public let type: String
    public let openIdConnectUrl: String
    public let description: String?

    public init(openIdConnectUrl: String, description: String? = nil) {
        self.type = "openIdConnect"
        self.openIdConnectUrl = openIdConnectUrl
        self.description = description
    }
}

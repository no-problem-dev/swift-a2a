/// タスクのプッシュ通知設定（A2A `TaskPushNotificationConfig`）。
///
/// v1.0 で旧 `PushNotificationConfig` と統合され、タスク ID・設定 ID を含む単一の型になりました。
public struct TaskPushNotificationConfig: Sendable, Hashable {
    /// ルーティング用の不透明識別子（`AgentInterface.tenant` と一致させる）。
    public var tenant: String?
    /// この設定の一意識別子。
    public var id: String?
    /// 対象タスクの ID。
    public var taskId: TaskID?
    /// 通知の送信先 URL。
    public var url: String
    /// このタスク／セッションに固有のトークン。
    public var token: String?
    /// 通知送信時の認証情報。
    public var authentication: AuthenticationInfo?

    public init(
        url: String,
        taskId: TaskID? = nil,
        id: String? = nil,
        tenant: String? = nil,
        token: String? = nil,
        authentication: AuthenticationInfo? = nil
    ) {
        self.url = url
        self.taskId = taskId
        self.id = id
        self.tenant = tenant
        self.token = token
        self.authentication = authentication
    }
}

extension TaskPushNotificationConfig: Codable {
    private enum CodingKeys: String, CodingKey {
        case tenant, id, taskId, url, token, authentication
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tenant = try container.decodeIfPresent(String.self, forKey: .tenant)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        taskId = try container.decodeOptionalID(forKey: .taskId)
        url = try container.decodeString(forKey: .url)
        token = try container.decodeIfPresent(String.self, forKey: .token)
        authentication = try container.decodeIfPresent(AuthenticationInfo.self, forKey: .authentication)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(tenant, forKey: .tenant)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(taskId, forKey: .taskId)
        try container.encodeIfNonEmpty(url, forKey: .url)
        try container.encodeIfPresent(token, forKey: .token)
        try container.encodeIfPresent(authentication, forKey: .authentication)
    }
}

/// プッシュ通知の認証情報（A2A `AuthenticationInfo`）。
public struct AuthenticationInfo: Sendable, Hashable {
    /// HTTP 認証スキーム（例 `Bearer`, `Basic`, `Digest`）。
    public var scheme: String
    /// 資格情報（スキーム依存。Bearer ならトークン等）。
    public var credentials: String?

    public init(scheme: String, credentials: String? = nil) {
        self.scheme = scheme
        self.credentials = credentials
    }
}

extension AuthenticationInfo: Codable {
    private enum CodingKeys: String, CodingKey { case scheme, credentials }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scheme = try container.decodeString(forKey: .scheme)
        credentials = try container.decodeIfPresent(String.self, forKey: .credentials)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfNonEmpty(scheme, forKey: .scheme)
        try container.encodeIfPresent(credentials, forKey: .credentials)
    }
}

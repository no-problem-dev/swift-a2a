/// Where to deliver a task's updates when the client is not listening on a stream.
///
/// v1.0 folded the older separate `PushNotificationConfig` into this single type, which is why the
/// task and config identifiers live here rather than in a wrapper.
public struct TaskPushNotificationConfig: Sendable, Hashable {
    /// An opaque routing identifier for multi-tenant deployments, matching `AgentInterface.tenant`.
    public var tenant: String?
    /// Identifies this configuration. The server assigns one when it is absent, and re-registering
    /// with the same value replaces the earlier configuration rather than adding a second.
    public var id: String?
    /// The task whose updates this covers. Required by the server, optional here because the
    /// binding fills it in from the request path.
    public var taskId: TaskID?
    /// The webhook to POST updates to.
    public var url: String
    /// A value the receiver can check to confirm a delivery is the one it asked for. Sent in the
    /// `X-A2A-Notification-Token` header, not the body.
    public var token: String?
    /// Credentials for the webhook itself. Carried through but never applied by the sender shipped
    /// here — supply your own sender if the webhook requires authentication.
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

/// Credentials an agent should present when calling a webhook.
public struct AuthenticationInfo: Sendable, Hashable {
    /// The HTTP authentication scheme: `Bearer`, `Basic`, `Digest`, and so on.
    public var scheme: String
    /// The credential itself, interpreted according to `scheme`.
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

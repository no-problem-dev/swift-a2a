import Foundation

// MARK: - PushNotificationConfig

/// プッシュ通知の設定
public struct PushNotificationConfig: Codable, Sendable, Equatable {
    /// 通知先URL
    public let url: String

    /// 認証トークン
    public let token: String?

    /// 認証情報
    public let authentication: AuthenticationInfo?

    public init(
        url: String,
        token: String? = nil,
        authentication: AuthenticationInfo? = nil
    ) {
        self.url = url
        self.token = token
        self.authentication = authentication
    }
}

// MARK: - AuthenticationInfo

/// プッシュ通知の認証情報
public struct AuthenticationInfo: Codable, Sendable, Equatable {
    /// 認証スキーム一覧
    public let schemes: [String]?

    /// 資格情報
    public let credentials: String?

    public init(schemes: [String]? = nil, credentials: String? = nil) {
        self.schemes = schemes
        self.credentials = credentials
    }
}

// MARK: - TaskPushNotificationConfig

/// タスク固有のプッシュ通知設定
public struct TaskPushNotificationConfig: Codable, Sendable, Equatable {
    /// タスクID
    public let taskId: String

    /// プッシュ通知設定
    public let pushNotificationConfig: PushNotificationConfig

    public init(taskId: String, pushNotificationConfig: PushNotificationConfig) {
        self.taskId = taskId
        self.pushNotificationConfig = pushNotificationConfig
    }
}

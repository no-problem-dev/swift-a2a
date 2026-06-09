import Foundation

// MARK: - SendMessage

/// `SendMessage` / `SendStreamingMessage` のリクエスト（A2A `SendMessageRequest`）。
public struct SendMessageRequest: Codable, Sendable, Hashable {
    public var message: Message
    public var configuration: SendMessageConfiguration?
    public var metadata: A2AMetadata?
    /// マルチテナント用ルーティング識別子。
    public var tenant: String?

    public init(
        message: Message,
        configuration: SendMessageConfiguration? = nil,
        metadata: A2AMetadata? = nil,
        tenant: String? = nil
    ) {
        self.message = message
        self.configuration = configuration
        self.metadata = metadata
        self.tenant = tenant
    }
}

/// 送信設定（A2A `SendMessageConfiguration`）。
public struct SendMessageConfiguration: Sendable, Hashable {
    /// クライアントが受理できる出力メディアタイプ。
    public var acceptedOutputModes: [String]
    /// タスク更新のプッシュ通知設定（送信時 `taskId` は空にする）。
    public var taskPushNotificationConfig: TaskPushNotificationConfig?
    /// 応答に含める履歴の最大件数（未設定=無制限、0=含めない）。
    public var historyLength: Int?
    /// `true` ならタスク作成後すぐに返す。`false`（既定）なら終端/中断状態まで待つ。
    public var returnImmediately: Bool

    public init(
        acceptedOutputModes: [String] = [],
        taskPushNotificationConfig: TaskPushNotificationConfig? = nil,
        historyLength: Int? = nil,
        returnImmediately: Bool = false
    ) {
        self.acceptedOutputModes = acceptedOutputModes
        self.taskPushNotificationConfig = taskPushNotificationConfig
        self.historyLength = historyLength
        self.returnImmediately = returnImmediately
    }
}

extension SendMessageConfiguration: Codable {
    private enum CodingKeys: String, CodingKey {
        case acceptedOutputModes, taskPushNotificationConfig, historyLength, returnImmediately
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        acceptedOutputModes = try container.decodeArray(forKey: .acceptedOutputModes)
        taskPushNotificationConfig = try container.decodeIfPresent(TaskPushNotificationConfig.self, forKey: .taskPushNotificationConfig)
        historyLength = try container.decodeIfPresent(Int.self, forKey: .historyLength)
        returnImmediately = try container.decodeBool(forKey: .returnImmediately)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfNonEmpty(acceptedOutputModes, forKey: .acceptedOutputModes)
        try container.encodeIfPresent(taskPushNotificationConfig, forKey: .taskPushNotificationConfig)
        try container.encodeIfPresent(historyLength, forKey: .historyLength)
        try container.encodeIfTrue(returnImmediately, forKey: .returnImmediately)
    }
}

// MARK: - Task operations

/// `GetTask` のリクエスト（A2A `GetTaskRequest`）。
public struct GetTaskRequest: Codable, Sendable, Hashable {
    public var id: TaskID
    public var historyLength: Int?
    public var tenant: String?

    public init(id: TaskID, historyLength: Int? = nil, tenant: String? = nil) {
        self.id = id
        self.historyLength = historyLength
        self.tenant = tenant
    }
}

/// `CancelTask` のリクエスト（A2A `CancelTaskRequest`）。
public struct CancelTaskRequest: Codable, Sendable, Hashable {
    public var id: TaskID
    public var metadata: A2AMetadata?
    public var tenant: String?

    public init(id: TaskID, metadata: A2AMetadata? = nil, tenant: String? = nil) {
        self.id = id
        self.metadata = metadata
        self.tenant = tenant
    }
}

/// `SubscribeToTask` のリクエスト（A2A `SubscribeToTaskRequest`）。
public struct SubscribeToTaskRequest: Codable, Sendable, Hashable {
    public var id: TaskID
    public var tenant: String?

    public init(id: TaskID, tenant: String? = nil) {
        self.id = id
        self.tenant = tenant
    }
}

/// `ListTasks` のリクエスト（A2A `ListTasksRequest`）。
public struct ListTasksRequest: Codable, Sendable, Hashable {
    public var contextId: ContextID?
    public var status: TaskState?
    public var pageSize: Int?
    public var pageToken: String?
    public var historyLength: Int?
    public var statusTimestampAfter: Date?
    public var includeArtifacts: Bool?
    public var tenant: String?

    public init(
        contextId: ContextID? = nil,
        status: TaskState? = nil,
        pageSize: Int? = nil,
        pageToken: String? = nil,
        historyLength: Int? = nil,
        statusTimestampAfter: Date? = nil,
        includeArtifacts: Bool? = nil,
        tenant: String? = nil
    ) {
        self.contextId = contextId
        self.status = status
        self.pageSize = pageSize
        self.pageToken = pageToken
        self.historyLength = historyLength
        self.statusTimestampAfter = statusTimestampAfter
        self.includeArtifacts = includeArtifacts
        self.tenant = tenant
    }
}

/// `ListTasks` の結果（A2A `ListTasksResponse`）。
public struct ListTasksResponse: Sendable, Hashable {
    public var tasks: [A2ATask]
    public var nextPageToken: String?
    public var pageSize: Int
    public var totalSize: Int

    public init(tasks: [A2ATask] = [], nextPageToken: String? = nil, pageSize: Int = 0, totalSize: Int = 0) {
        self.tasks = tasks
        self.nextPageToken = nextPageToken
        self.pageSize = pageSize
        self.totalSize = totalSize
    }
}

extension ListTasksResponse: Codable {
    private enum CodingKeys: String, CodingKey { case tasks, nextPageToken, pageSize, totalSize }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tasks = try container.decodeArray(forKey: .tasks)
        nextPageToken = try container.decodeIfPresent(String.self, forKey: .nextPageToken)
        pageSize = try container.decodeIfPresent(Int.self, forKey: .pageSize) ?? 0
        totalSize = try container.decodeIfPresent(Int.self, forKey: .totalSize) ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfNonEmpty(tasks, forKey: .tasks)
        // spec §246 MUST: nextPageToken は常に present（終端は空文字）。
        try container.encode(nextPageToken ?? "", forKey: .nextPageToken)
        try container.encode(pageSize, forKey: .pageSize)
        try container.encode(totalSize, forKey: .totalSize)
    }
}

// MARK: - Push notification config operations

/// `GetTaskPushNotificationConfig` のリクエスト。
public struct GetTaskPushNotificationConfigRequest: Codable, Sendable, Hashable {
    public var taskId: TaskID
    public var id: String
    public var tenant: String?

    public init(taskId: TaskID, id: String, tenant: String? = nil) {
        self.taskId = taskId
        self.id = id
        self.tenant = tenant
    }
}

/// `DeleteTaskPushNotificationConfig` のリクエスト。
public struct DeleteTaskPushNotificationConfigRequest: Codable, Sendable, Hashable {
    public var taskId: TaskID
    public var id: String
    public var tenant: String?

    public init(taskId: TaskID, id: String, tenant: String? = nil) {
        self.taskId = taskId
        self.id = id
        self.tenant = tenant
    }
}

/// `ListTaskPushNotificationConfigs` のリクエスト。
public struct ListTaskPushNotificationConfigsRequest: Codable, Sendable, Hashable {
    public var taskId: TaskID
    public var pageSize: Int?
    public var pageToken: String?
    public var tenant: String?

    public init(taskId: TaskID, pageSize: Int? = nil, pageToken: String? = nil, tenant: String? = nil) {
        self.taskId = taskId
        self.pageSize = pageSize
        self.pageToken = pageToken
        self.tenant = tenant
    }
}

/// `ListTaskPushNotificationConfigs` の結果。
public struct ListTaskPushNotificationConfigsResponse: Sendable, Hashable {
    public var configs: [TaskPushNotificationConfig]
    public var nextPageToken: String?

    public init(configs: [TaskPushNotificationConfig] = [], nextPageToken: String? = nil) {
        self.configs = configs
        self.nextPageToken = nextPageToken
    }
}

extension ListTaskPushNotificationConfigsResponse: Codable {
    private enum CodingKeys: String, CodingKey { case configs, nextPageToken }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        configs = try container.decodeArray(forKey: .configs)
        nextPageToken = try container.decodeIfPresent(String.self, forKey: .nextPageToken)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfNonEmpty(configs, forKey: .configs)
        try container.encodeIfPresent(nextPageToken, forKey: .nextPageToken)
    }
}

// MARK: - Extended Agent Card

/// `GetExtendedAgentCard` のリクエスト（A2A `GetExtendedAgentCardRequest`）。
public struct GetExtendedAgentCardRequest: Codable, Sendable, Hashable {
    public var tenant: String?
    public init(tenant: String? = nil) { self.tenant = tenant }
}

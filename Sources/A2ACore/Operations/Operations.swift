import Foundation

// MARK: - SendMessage

/// The request for both the streaming and non-streaming send operations, which differ only in how
/// the answer comes back.
public struct SendMessageRequest: Codable, Sendable, Hashable {
    /// What to send. Its `taskId` decides whether this continues a task or starts one.
    public var message: Message
    /// How the agent should answer.
    public var configuration: SendMessageConfiguration?
    /// Free-form data carried alongside the request.
    public var metadata: A2AMetadata?
    /// An opaque routing identifier for multi-tenant deployments.
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

/// How the agent should answer a send: what output the client can take, whether to wait, and
/// where to push updates if it does not.
public struct SendMessageConfiguration: Sendable, Hashable {
    /// Media types the client can handle. Advisory — nothing rejects an answer outside the list.
    public var acceptedOutputModes: [String]
    /// A webhook to register for this task in the same call. Leave its `taskId` empty; the server
    /// fills in the ID it assigns.
    public var taskPushNotificationConfig: TaskPushNotificationConfig?
    /// How many of the most recent messages to include in the returned task. Absent means all;
    /// `0` means none.
    public var historyLength: Int?
    /// Whether to return as soon as the task exists rather than waiting for it to finish.
    ///
    /// `false`, the default, waits for a terminal or interrupted state. `true` returns a
    /// just-submitted task while work continues in the background — follow it with a subscription
    /// or a push configuration, since the returned snapshot will not update itself.
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

/// Asks for one task by ID, optionally trimming its history.
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

/// Asks an agent to stop a task.
///
/// The agent decides: a task already in a terminal state cannot be canceled, and one whose
/// executor declines to reach the canceled state is reported as not cancelable.
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

/// Asks to follow a task that is already running.
///
/// Only non-terminal tasks can be subscribed to; the stream opens with a snapshot of the task as
/// it stands.
public struct SubscribeToTaskRequest: Codable, Sendable, Hashable {
    public var id: TaskID
    public var tenant: String?

    public init(id: TaskID, tenant: String? = nil) {
        self.id = id
        self.tenant = tenant
    }
}

/// Asks for a page of tasks, filtered and ordered newest first by status timestamp.
///
/// Filters combine with AND. Paging is by cursor: pass the previous response's `nextPageToken`,
/// and stop when it comes back empty.
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

/// A page of tasks, ordered by status timestamp descending.
public struct ListTasksResponse: Sendable, Hashable {
    /// The tasks on this page.
    public var tasks: [A2ATask]
    /// The cursor for the next page, or the empty string on the last one. Always present in the
    /// encoded form, even when empty.
    public var nextPageToken: String?
    /// The page size actually applied, which may differ from the one requested.
    public var pageSize: Int
    /// How many tasks match the filters in total, across all pages.
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
        // Written unconditionally, empty string included: the specification requires the field to
        // be present, which overrides the proto3 rule of omitting default values.
        try container.encode(nextPageToken ?? "", forKey: .nextPageToken)
        try container.encode(pageSize, forKey: .pageSize)
        try container.encode(totalSize, forKey: .totalSize)
    }
}

// MARK: - Push notification config operations

/// Asks for one webhook configuration by task and config ID.
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

/// Asks to remove one webhook configuration.
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

/// Asks for the webhook configurations registered on a task.
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

/// The webhook configurations registered on a task.
public struct ListTaskPushNotificationConfigsResponse: Sendable, Hashable {
    /// The configurations. The in-memory store returns them all in one response.
    public var configs: [TaskPushNotificationConfig]
    /// The cursor for the next page. Left absent by the store shipped here.
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

/// Asks for the fuller agent card available to authenticated callers.
///
/// Fails unless the agent advertises `extendedAgentCard` in its capabilities.
public struct GetExtendedAgentCardRequest: Codable, Sendable, Hashable {
    public var tenant: String?
    public init(tenant: String? = nil) { self.tenant = tenant }
}

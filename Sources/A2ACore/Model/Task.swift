import Foundation

/// A unit of work an agent carries out, carrying its state, its outputs and the exchange so far.
///
/// Named `A2ATask` rather than `Task` to avoid colliding with Swift concurrency's `Task`.
public struct A2ATask: Sendable, Hashable {
    /// Identifies this task. The server assigns it.
    public var id: TaskID
    /// The conversation this task belongs to.
    public var contextId: ContextID?
    /// Where the task is now, and when it got there.
    public var status: TaskStatus
    /// What the task has produced so far. Grows as a streaming agent emits artifact updates.
    public var artifacts: [Artifact]
    /// The messages exchanged, oldest first. A request may ask for only the most recent few, so a
    /// short history does not mean a short conversation.
    public var history: [Message]
    /// Free-form data carried alongside the task.
    public var metadata: A2AMetadata?

    public init(
        id: TaskID,
        contextId: ContextID? = nil,
        status: TaskStatus,
        artifacts: [Artifact] = [],
        history: [Message] = [],
        metadata: A2AMetadata? = nil
    ) {
        self.id = id
        self.contextId = contextId
        self.status = status
        self.artifacts = artifacts
        self.history = history
        self.metadata = metadata
    }
}

extension A2ATask: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, contextId, status, artifacts, history, metadata
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeID(forKey: .id)
        contextId = try container.decodeOptionalID(forKey: .contextId)
        status = try container.decodeIfPresent(TaskStatus.self, forKey: .status) ?? TaskStatus(state: .unspecified)
        artifacts = try container.decodeArray(forKey: .artifacts)
        history = try container.decodeArray(forKey: .history)
        metadata = try container.decodeIfPresent(A2AMetadata.self, forKey: .metadata)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfNonEmpty(id, forKey: .id)
        try container.encodeIfPresent(contextId, forKey: .contextId)
        try container.encode(status, forKey: .status)
        try container.encodeIfNonEmpty(artifacts, forKey: .artifacts)
        try container.encodeIfNonEmpty(history, forKey: .history)
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }
}

/// A task's state together with when it was recorded and any message explaining it.
public struct TaskStatus: Sendable, Hashable {
    /// The state itself.
    public var state: TaskState
    /// The agent's accompanying message — typically the question when work stopped for input, or
    /// the reason when it failed. Appended to the task's history when the status is applied.
    public var message: Message?
    /// When this state was recorded, sent as an RFC 3339 UTC timestamp. Absent on a status the
    /// agent did not stamp, which pushes the task to the end of a timestamp-ordered listing.
    public var timestamp: Date?

    public init(state: TaskState, message: Message? = nil, timestamp: Date? = nil) {
        self.state = state
        self.message = message
        self.timestamp = timestamp
    }
}

extension TaskStatus: Codable {
    private enum CodingKeys: String, CodingKey { case state, message, timestamp }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        state = try container.decodeProtoEnum(forKey: .state)
        message = try container.decodeIfPresent(Message.self, forKey: .message)
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(proto: state, forKey: .state)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(timestamp, forKey: .timestamp)
    }
}

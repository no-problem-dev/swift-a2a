/// Reports that a task moved to a new state.
///
/// An event carrying a terminal or interrupted state ends the stream that delivered it.
public struct TaskStatusUpdateEvent: Sendable, Hashable {
    /// The task that moved.
    public var taskId: TaskID
    /// The conversation the task belongs to.
    public var contextId: ContextID
    /// The state it moved to. Its message, if any, is appended to the task's history.
    public var status: TaskStatus
    /// Free-form data carried alongside the event.
    public var metadata: A2AMetadata?

    public init(taskId: TaskID, contextId: ContextID, status: TaskStatus, metadata: A2AMetadata? = nil) {
        self.taskId = taskId
        self.contextId = contextId
        self.status = status
        self.metadata = metadata
    }
}

extension TaskStatusUpdateEvent: Codable {
    private enum CodingKeys: String, CodingKey { case taskId, contextId, status, metadata }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskId = try container.decodeID(forKey: .taskId)
        contextId = try container.decodeID(forKey: .contextId)
        status = try container.decodeIfPresent(TaskStatus.self, forKey: .status) ?? TaskStatus(state: .unspecified)
        metadata = try container.decodeIfPresent(A2AMetadata.self, forKey: .metadata)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfNonEmpty(taskId, forKey: .taskId)
        try container.encodeIfNonEmpty(contextId, forKey: .contextId)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }
}

/// Delivers an artifact, or another piece of one already in flight.
///
/// Never ends a stream: a task keeps running after producing output.
public struct TaskArtifactUpdateEvent: Sendable, Hashable {
    /// The task that produced the artifact.
    public var taskId: TaskID
    /// The conversation the task belongs to.
    public var contextId: ContextID
    /// The artifact, whole or in part.
    public var artifact: Artifact
    /// Whether to append these parts to the artifact already held under this ID rather than
    /// replace it. An unknown ID is added either way.
    public var append: Bool
    /// Whether this is the last piece of this artifact. Recorded, but nothing here acts on it —
    /// an artifact is complete when the sender stops sending.
    public var lastChunk: Bool
    /// Free-form data carried alongside the event.
    public var metadata: A2AMetadata?

    public init(
        taskId: TaskID,
        contextId: ContextID,
        artifact: Artifact,
        append: Bool = false,
        lastChunk: Bool = false,
        metadata: A2AMetadata? = nil
    ) {
        self.taskId = taskId
        self.contextId = contextId
        self.artifact = artifact
        self.append = append
        self.lastChunk = lastChunk
        self.metadata = metadata
    }
}

extension TaskArtifactUpdateEvent: Codable {
    private enum CodingKeys: String, CodingKey {
        case taskId, contextId, artifact, append, lastChunk, metadata
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskId = try container.decodeID(forKey: .taskId)
        contextId = try container.decodeID(forKey: .contextId)
        artifact = try container.decode(Artifact.self, forKey: .artifact)
        append = try container.decodeBool(forKey: .append)
        lastChunk = try container.decodeBool(forKey: .lastChunk)
        metadata = try container.decodeIfPresent(A2AMetadata.self, forKey: .metadata)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfNonEmpty(taskId, forKey: .taskId)
        try container.encodeIfNonEmpty(contextId, forKey: .contextId)
        try container.encode(artifact, forKey: .artifact)
        try container.encodeIfTrue(append, forKey: .append)
        try container.encodeIfTrue(lastChunk, forKey: .lastChunk)
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }
}

/// What a non-streaming send comes back with: either a task to follow, or a direct reply.
///
/// An agent answers with a message when the exchange needs no tracked work — no task is created
/// and there is nothing to poll afterwards.
public enum SendMessageResponse: Sendable, Hashable {
    /// A task was created or advanced.
    case task(A2ATask)
    /// The agent replied outright.
    case message(Message)
}

extension SendMessageResponse: Codable {
    private enum CodingKeys: String, CodingKey {
        case task, message
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.task) {
            self = .task(try container.decode(A2ATask.self, forKey: .task))
        } else if container.contains(.message) {
            self = .message(try container.decode(Message.self, forKey: .message))
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "SendMessageResponse must contain one of: task, message"
                )
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .task(let value): try container.encode(value, forKey: .task)
        case .message(let value): try container.encode(value, forKey: .message)
        }
    }
}

/// One event on a stream, and the payload of a push notification.
///
/// Events arrive in the order the agent produced them. A `message`, or a `task` or `statusUpdate`
/// whose state is terminal or interrupted, is the last event of a stream.
public enum StreamResponse: Sendable, Hashable {
    /// A whole task snapshot. Always the first event of a subscription.
    case task(A2ATask)
    /// A direct reply from the agent, which ends the stream.
    case message(Message)
    /// The task changed state.
    case statusUpdate(TaskStatusUpdateEvent)
    /// The task produced output.
    case artifactUpdate(TaskArtifactUpdateEvent)
}

extension StreamResponse: Codable {
    private enum CodingKeys: String, CodingKey {
        case task, message, statusUpdate, artifactUpdate
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.task) {
            self = .task(try container.decode(A2ATask.self, forKey: .task))
        } else if container.contains(.message) {
            self = .message(try container.decode(Message.self, forKey: .message))
        } else if container.contains(.statusUpdate) {
            self = .statusUpdate(try container.decode(TaskStatusUpdateEvent.self, forKey: .statusUpdate))
        } else if container.contains(.artifactUpdate) {
            self = .artifactUpdate(try container.decode(TaskArtifactUpdateEvent.self, forKey: .artifactUpdate))
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "StreamResponse must contain one of: task, message, statusUpdate, artifactUpdate"
                )
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .task(let value): try container.encode(value, forKey: .task)
        case .message(let value): try container.encode(value, forKey: .message)
        case .statusUpdate(let value): try container.encode(value, forKey: .statusUpdate)
        case .artifactUpdate(let value): try container.encode(value, forKey: .artifactUpdate)
        }
    }
}

extension StreamResponse {
    /// Every content part in the event, whichever kind it is.
    ///
    /// For a task snapshot this is the artifact parts followed by the parts of the status message,
    /// so the two sources are not distinguishable in the result.
    public var parts: [Part] {
        switch self {
        case .task(let task):
            task.artifacts.flatMap(\.parts) + (task.status.message?.parts ?? [])
        case .message(let message):
            message.parts
        case .statusUpdate(let update):
            update.status.message?.parts ?? []
        case .artifactUpdate(let update):
            update.artifact.parts
        }
    }

    /// The text of every text part, joined; non-text parts are skipped.
    ///
    /// - Parameter delimiter: What to place between parts. A newline by default.
    public func text(delimiter: String = "\n") -> String {
        parts.compactMap(\.text).joined(separator: delimiter)
    }
}

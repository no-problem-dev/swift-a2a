/// タスクのステータス変化を通知するイベント（A2A `TaskStatusUpdateEvent`）。
public struct TaskStatusUpdateEvent: Sendable, Hashable {
    /// 変化したタスクの ID。
    public var taskId: TaskID
    /// タスクが属するコンテキストの ID。
    public var contextId: ContextID
    /// 新しいステータス。
    public var status: TaskStatus
    /// 付随メタデータ。
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

/// アーティファクト生成・更新を通知するイベント（A2A `TaskArtifactUpdateEvent`）。
public struct TaskArtifactUpdateEvent: Sendable, Hashable {
    /// 対象タスクの ID。
    public var taskId: TaskID
    /// タスクが属するコンテキストの ID。
    public var contextId: ContextID
    /// 生成・更新されたアーティファクト。
    public var artifact: Artifact
    /// `true` なら同一 ID の既存アーティファクトに追記する。
    public var append: Bool
    /// `true` ならこのアーティファクトの最終チャンク。
    public var lastChunk: Bool
    /// 付随メタデータ。
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

/// 非ストリーミング送信（`SendMessage`）の結果（A2A `SendMessageResponse`、oneof）。
public enum SendMessageResponse: Sendable, Hashable {
    /// 作成・更新されたタスク。
    case task(A2ATask)
    /// エージェントからのメッセージ。
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

/// ストリーミング／プッシュ通知で配信されるイベント（A2A `StreamResponse`、oneof）。
public enum StreamResponse: Sendable, Hashable {
    /// タスクの現在状態。
    case task(A2ATask)
    /// エージェントからのメッセージ。
    case message(Message)
    /// ステータス更新イベント。
    case statusUpdate(TaskStatusUpdateEvent)
    /// アーティファクト更新イベント。
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
    /// ペイロード（task / message / statusUpdate / artifactUpdate）に含まれる全 `Part` を取り出す。
    /// a2a-python の Part 抽出ヘルパ群に相当する横断アクセサ。
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

    /// ペイロードの全テキストを結合して返す（a2a-python `get_stream_response_text` 相当）。
    public func text(delimiter: String = "\n") -> String {
        parts.compactMap(\.text).joined(separator: delimiter)
    }
}

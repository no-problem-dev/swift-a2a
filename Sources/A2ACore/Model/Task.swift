import Foundation

/// A2A の中心的な作業単位（A2A `Task`）。現在の状態・成果物・対話履歴を保持する。
public struct A2ATask: Sendable, Hashable {
    /// タスクの一意識別子（サーバが採番）。
    public var id: TaskID
    /// 一連の対話（タスク・メッセージ）をまとめるコンテキスト ID。
    public var contextId: ContextID?
    /// 現在のステータス。
    public var status: TaskStatus
    /// タスクの出力成果物。
    public var artifacts: [Artifact]
    /// タスクの対話履歴。
    public var history: [Message]
    /// 付随メタデータ。
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

/// タスクのステータス（A2A `TaskStatus`）。
public struct TaskStatus: Sendable, Hashable {
    /// 現在の状態。
    public var state: TaskState
    /// ステータスに付随するメッセージ。
    public var message: Message?
    /// ステータス記録時刻（RFC 3339 / UTC）。
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

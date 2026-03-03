import Foundation

// MARK: - TaskStatusUpdateEvent

/// タスクステータス更新イベント
public struct TaskStatusUpdateEvent: Codable, Sendable, Equatable {
    /// タスクID
    public let id: String

    /// 更新されたステータス
    public let status: TaskStatus

    /// 最終イベントかどうか
    public let final: Bool?

    /// メタデータ
    public let metadata: [String: AnyCodable]?

    public init(
        id: String,
        status: TaskStatus,
        final: Bool? = nil,
        metadata: [String: AnyCodable]? = nil
    ) {
        self.id = id
        self.status = status
        self.final = `final`
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case status
        case `final` = "final"
        case metadata
    }
}

// MARK: - TaskArtifactUpdateEvent

/// タスクアーティファクト更新イベント
public struct TaskArtifactUpdateEvent: Codable, Sendable, Equatable {
    /// タスクID
    public let id: String

    /// 更新されたアーティファクト
    public let artifact: Artifact

    /// メタデータ
    public let metadata: [String: AnyCodable]?

    public init(
        id: String,
        artifact: Artifact,
        metadata: [String: AnyCodable]? = nil
    ) {
        self.id = id
        self.artifact = artifact
        self.metadata = metadata
    }
}

// MARK: - StreamResponse

/// ストリーミングレスポンス
///
/// SSEストリームから受信するイベントの型です。
public enum StreamResponse: Sendable, Equatable {
    /// タスクステータス更新
    case statusUpdate(TaskStatusUpdateEvent)
    /// アーティファクト更新
    case artifactUpdate(TaskArtifactUpdateEvent)
}

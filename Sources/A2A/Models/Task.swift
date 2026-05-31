import Foundation
import StructuredDataCore

// MARK: - A2ATask

/// A2Aタスク
///
/// エージェント間でやり取りされるタスクの状態を表現します。
public struct A2ATask: Codable, Sendable, Equatable {
    /// タスクID
    public let id: String

    /// セッションID
    public let sessionId: String?

    /// タスクの現在のステータス
    public let status: TaskStatus

    /// タスクに関連するアーティファクト
    public let artifacts: [Artifact]?

    /// タスクの履歴（メッセージ一覧）
    public let history: [Message]?

    /// メタデータ
    public let metadata: [String: StructuredValue]?

    public init(
        id: String,
        sessionId: String? = nil,
        status: TaskStatus,
        artifacts: [Artifact]? = nil,
        history: [Message]? = nil,
        metadata: [String: StructuredValue]? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.status = status
        self.artifacts = artifacts
        self.history = history
        self.metadata = metadata
    }
}

// MARK: - TaskState

/// タスクの状態（7状態）
public enum TaskState: String, Codable, Sendable, Equatable {
    /// 送信済み
    case submitted
    /// 処理中
    case working
    /// 入力が必要
    case inputRequired = "input-required"
    /// 完了
    case completed
    /// キャンセル済み
    case canceled
    /// 失敗
    case failed
    /// 認証が必要
    case authRequired = "auth-required"
}

extension TaskState {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        // Try to match known cases first
        if let knownCase = TaskState(rawValue: rawValue) {
            self = knownCase
        } else {
            // Unknown values default to submitted
            self = .submitted
        }
    }
}

// MARK: - TaskStatus

/// タスクのステータス情報
public struct TaskStatus: Codable, Sendable, Equatable {
    /// 現在の状態
    public let state: TaskState

    /// ステータスメッセージ
    public let message: Message?

    /// タイムスタンプ
    public let timestamp: Date?

    public init(
        state: TaskState,
        message: Message? = nil,
        timestamp: Date? = nil
    ) {
        self.state = state
        self.message = message
        self.timestamp = timestamp
    }
}

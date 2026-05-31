import Foundation
import StructuredDataCore

// MARK: - MessageSendParams

/// message/send のパラメータ
public struct MessageSendParams: Codable, Sendable, Equatable {
    /// 送信するメッセージ
    public let message: Message

    /// メッセージ送信設定
    public let configuration: MessageSendConfiguration?

    /// メタデータ
    public let metadata: [String: StructuredValue]?

    public init(
        message: Message,
        configuration: MessageSendConfiguration? = nil,
        metadata: [String: StructuredValue]? = nil
    ) {
        self.message = message
        self.configuration = configuration
        self.metadata = metadata
    }
}

// MARK: - MessageSendConfiguration

/// メッセージ送信の設定
public struct MessageSendConfiguration: Codable, Sendable, Equatable {
    /// 受け入れ可能な出力モード
    public let acceptedOutputModes: [String]?

    /// プッシュ通知設定
    public let pushNotificationConfig: PushNotificationConfig?

    /// 履歴の長さ制限
    public let historyLength: Int?

    /// ブロッキングモード
    public let blocking: Bool?

    /// タスクID（既存タスクへのメッセージ送信時）
    public let taskId: String?

    /// セッションID
    public let sessionId: String?

    public init(
        acceptedOutputModes: [String]? = nil,
        pushNotificationConfig: PushNotificationConfig? = nil,
        historyLength: Int? = nil,
        blocking: Bool? = nil,
        taskId: String? = nil,
        sessionId: String? = nil
    ) {
        self.acceptedOutputModes = acceptedOutputModes
        self.pushNotificationConfig = pushNotificationConfig
        self.historyLength = historyLength
        self.blocking = blocking
        self.taskId = taskId
        self.sessionId = sessionId
    }
}

// MARK: - SendMessageResult

/// message/send の結果
///
/// タスクまたはアーティファクト更新イベントを返します。
public enum SendMessageResult: Sendable, Equatable {
    /// タスク応答
    case task(A2ATask)
    /// アーティファクト応答
    case artifact(Artifact)
}

extension SendMessageResult: Codable {
    private enum CodingKeys: String, CodingKey {
        case status
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // If 'status' field is present, it's a Task
        if container.contains(.status) {
            self = .task(try A2ATask(from: decoder))
        } else {
            // Otherwise, it's an Artifact
            self = .artifact(try Artifact(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .task(let task):
            try task.encode(to: encoder)
        case .artifact(let artifact):
            try artifact.encode(to: encoder)
        }
    }
}

// MARK: - GetTaskParams

/// tasks/get のパラメータ
public struct GetTaskParams: Codable, Sendable, Equatable {
    /// タスクID
    public let id: String

    /// 履歴の長さ
    public let historyLength: Int?

    /// メタデータ
    public let metadata: [String: StructuredValue]?

    public init(id: String, historyLength: Int? = nil, metadata: [String: StructuredValue]? = nil) {
        self.id = id
        self.historyLength = historyLength
        self.metadata = metadata
    }
}

// MARK: - CancelTaskParams

/// tasks/cancel のパラメータ
public struct CancelTaskParams: Codable, Sendable, Equatable {
    /// タスクID
    public let id: String

    /// メタデータ
    public let metadata: [String: StructuredValue]?

    public init(id: String, metadata: [String: StructuredValue]? = nil) {
        self.id = id
        self.metadata = metadata
    }
}

// MARK: - ListTasksParams

/// tasks/list のパラメータ
public struct ListTasksParams: Codable, Sendable, Equatable {
    /// セッションID
    public let sessionId: String?

    /// メタデータ
    public let metadata: [String: StructuredValue]?

    public init(sessionId: String? = nil, metadata: [String: StructuredValue]? = nil) {
        self.sessionId = sessionId
        self.metadata = metadata
    }
}

// MARK: - TaskResubscribeParams

/// tasks/resubscribe のパラメータ
public struct TaskResubscribeParams: Codable, Sendable, Equatable {
    /// タスクID
    public let id: String

    /// メタデータ
    public let metadata: [String: StructuredValue]?

    public init(id: String, metadata: [String: StructuredValue]? = nil) {
        self.id = id
        self.metadata = metadata
    }
}

// MARK: - SetPushNotificationParams

/// tasks/pushNotification/set のパラメータ
public struct SetPushNotificationParams: Codable, Sendable, Equatable {
    /// タスクID
    public let taskId: String

    /// プッシュ通知設定
    public let pushNotificationConfig: PushNotificationConfig

    public init(taskId: String, pushNotificationConfig: PushNotificationConfig) {
        self.taskId = taskId
        self.pushNotificationConfig = pushNotificationConfig
    }
}

// MARK: - GetPushNotificationParams

/// tasks/pushNotification/get のパラメータ
public struct GetPushNotificationParams: Codable, Sendable, Equatable {
    /// タスクID
    public let taskId: String

    public init(taskId: String) {
        self.taskId = taskId
    }
}

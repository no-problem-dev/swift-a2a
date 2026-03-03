import Foundation

// MARK: - A2AMethod

/// A2Aプロトコルのメソッド定義（11メソッド）
public enum A2AMethod: String, Sendable, Equatable, CaseIterable {
    // メッセージ送信
    case messageSend = "message/send"
    case messageStream = "message/stream"

    // タスク管理
    case tasksGet = "tasks/get"
    case tasksCancel = "tasks/cancel"
    case tasksResubscribe = "tasks/resubscribe"

    // タスク一覧
    case tasksList = "tasks/list"

    // プッシュ通知
    case tasksPushNotificationSet = "tasks/pushNotification/set"
    case tasksPushNotificationGet = "tasks/pushNotification/get"

    // エージェントカード
    case agentCardGet = "agent/card"

    // 認証
    case agentAuthenticatedExtendedCard = "agent/authenticatedExtendedCard"

    // 拡張
    case extensionSend = "extension/send"
}

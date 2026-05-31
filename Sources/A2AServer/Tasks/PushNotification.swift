import A2ACore

/// プッシュ通知設定の永続化（a2a-python `PushNotificationConfigStore`）。
public protocol PushNotificationConfigStore: Sendable {
    func set(_ config: TaskPushNotificationConfig) async throws -> TaskPushNotificationConfig
    func get(taskId: TaskID) async throws -> [TaskPushNotificationConfig]
    func delete(taskId: TaskID, configId: String) async throws
}

/// タスク更新を webhook へ送信する（a2a-python `PushNotificationSender`）。
/// 実 HTTP 送信は HTTP 依存を持つ上位ターゲットで実装する（A2AServer は依存最小を維持）。
public protocol PushNotificationSender: Sendable {
    func send(_ event: StreamResponse, to config: TaskPushNotificationConfig) async
}

public actor InMemoryPushNotificationConfigStore: PushNotificationConfigStore {
    private var configs: [TaskID: [TaskPushNotificationConfig]] = [:]

    public init() {}

    public func set(_ config: TaskPushNotificationConfig) async throws -> TaskPushNotificationConfig {
        guard let taskId = config.taskId else {
            throw A2AServerError.invalidParams("TaskPushNotificationConfig.taskId is required")
        }
        var list = configs[taskId] ?? []
        if let id = config.id, let index = list.firstIndex(where: { $0.id == id }) {
            list[index] = config
        } else {
            list.append(config)
        }
        configs[taskId] = list
        return config
    }

    public func get(taskId: TaskID) async throws -> [TaskPushNotificationConfig] {
        configs[taskId] ?? []
    }

    public func delete(taskId: TaskID, configId: String) async throws {
        configs[taskId]?.removeAll { $0.id == configId }
    }
}

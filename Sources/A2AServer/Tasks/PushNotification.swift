import A2ACore

/// タスクのプッシュ通知設定を永続化するインターフェース（a2a-python `PushNotificationConfigStore`）。
public protocol PushNotificationConfigStore: Sendable {
    /// 設定を保存（新規・更新）する。
    func set(_ config: TaskPushNotificationConfig) async throws -> TaskPushNotificationConfig
    /// タスクの設定一覧を取得する。
    func get(taskId: TaskID) async throws -> [TaskPushNotificationConfig]
    /// 設定を削除する。
    func delete(taskId: TaskID, configId: String) async throws
}

/// タスク更新を webhook へ送信するインターフェース（a2a-python `PushNotificationSender`）。
///
/// 実際の HTTP 送信は HTTP 依存を持つ上位ターゲットで実装します（A2AServer は依存最小を維持）。
public protocol PushNotificationSender: Sendable {
    /// 設定済み webhook へ `StreamResponse` ペイロードを送信する。
    func send(_ event: StreamResponse, to config: TaskPushNotificationConfig) async
}

/// メモリ内 `PushNotificationConfigStore` 実装（a2a-python `InMemoryPushNotificationConfigStore`）。
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

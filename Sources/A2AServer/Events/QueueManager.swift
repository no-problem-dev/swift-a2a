import A2ACore

/// タスク ID ごとの `EventQueue` を管理するインターフェース（a2a-python `QueueManager`）。
///
/// streaming 応答と `tasks:subscribe` が同一タスクのイベントを共有するために使います。
public protocol QueueManager: Sendable {
    /// タスクにキューを登録する。
    func add(_ taskId: TaskID, queue: EventQueue) async
    /// タスクのキューを取得する。無ければ `nil`。
    func get(_ taskId: TaskID) async -> EventQueue?
    /// タスクのキューを閉じて破棄する。
    func close(_ taskId: TaskID) async
    /// 既存キューを返すか、無ければ生成して登録する。
    func createOrGet(_ taskId: TaskID) async -> EventQueue
}

/// メモリ内 `QueueManager` 実装（a2a-python `InMemoryQueueManager`）。
public actor InMemoryQueueManager: QueueManager {
    private var queues: [TaskID: EventQueue] = [:]

    public init() {}

    public func add(_ taskId: TaskID, queue: EventQueue) async {
        queues[taskId] = queue
    }

    public func get(_ taskId: TaskID) async -> EventQueue? {
        queues[taskId]
    }

    public func close(_ taskId: TaskID) async {
        if let queue = queues[taskId] {
            await queue.close()
            queues[taskId] = nil
        }
    }

    public func createOrGet(_ taskId: TaskID) async -> EventQueue {
        if let existing = queues[taskId] {
            return existing
        }
        let queue = EventQueue()
        queues[taskId] = queue
        return queue
    }
}

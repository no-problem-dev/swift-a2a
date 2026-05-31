import A2ACore

/// タスク ID ごとの `EventQueue` を管理する（a2a-python `QueueManager`）。streaming と subscribe で共有。
public protocol QueueManager: Sendable {
    func add(_ taskId: TaskID, queue: EventQueue) async
    func get(_ taskId: TaskID) async -> EventQueue?
    func close(_ taskId: TaskID) async
    func createOrGet(_ taskId: TaskID) async -> EventQueue
}

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

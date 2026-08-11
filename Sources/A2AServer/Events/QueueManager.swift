import A2ACore

/// Keeps one event queue per running task, so a later subscription can join the stream a send
/// already started.
///
/// A queue exists only while its task is running: the handler closes and unregisters it when the
/// executor finishes, and a subscription to a task with no live queue cannot be served.
///
/// Implement this over shared storage to run more than one server process; the in-memory
/// implementation confines a task's stream to the process that started it.
public protocol QueueManager: Sendable {
    /// Registers an existing queue under a task ID, replacing any already registered.
    func add(_ taskId: TaskID, queue: EventQueue) async
    /// Returns the task's queue, or `nil` if it has none — which is the case once the task has
    /// finished.
    func get(_ taskId: TaskID) async -> EventQueue?
    /// Closes the task's queue and unregisters it, finishing every stream tapped from it.
    func close(_ taskId: TaskID) async
    /// Returns the task's queue, creating and registering one if it has none.
    func createOrGet(_ taskId: TaskID) async -> EventQueue
}

/// Holds queues in a dictionary. Suitable for a single process; queues do not survive a restart
/// and are invisible to other instances.
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

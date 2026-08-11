import A2ACore

/// Folds a task's event stream into its stored state: applies each event to the task and saves it.
///
/// One instance per task per run. A status update replaces the status and appends its message to
/// the history; an artifact update either appends to the artifact with the same ID or replaces it;
/// a whole-task event overwrites everything; a message event changes nothing, since a direct reply
/// is not part of a task.
///
/// Every applied event triggers a save, so a chatty executor writes to the store as often as it
/// publishes.
public actor TaskManager {
    private let taskId: TaskID
    private let contextId: ContextID
    private let store: any TaskStore
    private let callContext: ServerCallContext
    private var currentTask: A2ATask?

    public init(taskId: TaskID, contextId: ContextID, store: any TaskStore, initialTask: A2ATask? = nil, callContext: ServerCallContext = ServerCallContext()) {
        self.taskId = taskId
        self.contextId = contextId
        self.store = store
        self.callContext = callContext
        self.currentTask = initialTask
    }

    /// The task as folded so far, or `nil` if no event has created it yet.
    public func getTask() -> A2ATask? { currentTask }

    /// Applies one event and persists the result.
    ///
    /// An update arriving before any task exists synthesizes a submitted task rather than failing,
    /// so an executor may publish a status update as its first event.
    ///
    /// - Returns: The event, unchanged, so this can sit in a forwarding chain.
    /// - Throws: Whatever the store throws. The event has already been applied in memory when it
    ///   does, so the store and this manager can disagree.
    @discardableResult
    public func process(_ event: StreamResponse) async throws -> StreamResponse {
        switch event {
        case .task(let task):
            currentTask = task
            try await store.save(task, context: callContext)

        case .message:
            break

        case .statusUpdate(let update):
            var task = ensureTask()
            task.status = update.status
            if let message = update.status.message {
                task.history.append(message)
            }
            currentTask = task
            try await store.save(task, context: callContext)

        case .artifactUpdate(let update):
            var task = ensureTask()
            upsert(artifact: update.artifact, append: update.append, into: &task)
            currentTask = task
            try await store.save(task, context: callContext)
        }
        return event
    }

    private func ensureTask() -> A2ATask {
        if let currentTask { return currentTask }
        let task = A2ATask(id: taskId, contextId: contextId, status: TaskStatus(state: .submitted))
        currentTask = task
        return task
    }

    private func upsert(artifact: Artifact, append: Bool, into task: inout A2ATask) {
        if let index = task.artifacts.firstIndex(where: { $0.artifactId == artifact.artifactId }) {
            if append {
                task.artifacts[index].parts.append(contentsOf: artifact.parts)
            } else {
                task.artifacts[index] = artifact
            }
        } else {
            task.artifacts.append(artifact)
        }
    }
}

import A2ACore

/// `StreamResponse` から単一タスクの状態を再構成・永続化する reducer（a2a-python `TaskManager`）。
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

    public func getTask() -> A2ATask? { currentTask }

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

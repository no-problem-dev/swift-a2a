import A2ACore
import Foundation

/// `AgentExecutor` がタスク更新を publish するヘルパ（a2a-python `TaskUpdater`）。
/// 終端状態（completed/failed/canceled/rejected）到達後の更新はエラーになる。
public actor TaskUpdater {
    private let eventQueue: EventQueue
    private let taskId: TaskID
    private let contextId: ContextID
    private var terminalReached = false

    public init(eventQueue: EventQueue, taskId: TaskID, contextId: ContextID) {
        self.eventQueue = eventQueue
        self.taskId = taskId
        self.contextId = contextId
    }

    public func updateStatus(
        _ state: TaskState,
        message: Message? = nil,
        metadata: A2AMetadata? = nil
    ) async throws {
        if terminalReached {
            throw A2AServerError.internalError("Task \(taskId) is already in a terminal state.")
        }
        if state.isTerminal {
            terminalReached = true
        }
        let status = TaskStatus(state: state, message: message, timestamp: Date())
        let event = TaskStatusUpdateEvent(taskId: taskId, contextId: contextId, status: status, metadata: metadata)
        await eventQueue.enqueue(.statusUpdate(event))
    }

    public func addArtifact(
        _ parts: [Part],
        artifactId: ArtifactID = ArtifactID(UUID().uuidString),
        name: String? = nil,
        description: String? = nil,
        append: Bool = false,
        lastChunk: Bool = false,
        metadata: A2AMetadata? = nil
    ) async {
        let artifact = Artifact(
            artifactId: artifactId,
            name: name,
            description: description,
            parts: parts,
            metadata: metadata
        )
        let event = TaskArtifactUpdateEvent(
            taskId: taskId,
            contextId: contextId,
            artifact: artifact,
            append: append,
            lastChunk: lastChunk
        )
        await eventQueue.enqueue(.artifactUpdate(event))
    }

    public func makeAgentMessage(_ parts: [Part], metadata: A2AMetadata? = nil) -> Message {
        Message(
            messageId: MessageID(UUID().uuidString),
            role: .agent,
            parts: parts,
            contextId: contextId,
            taskId: taskId,
            metadata: metadata
        )
    }

    public func submit(message: Message? = nil) async throws {
        try await updateStatus(.submitted, message: message)
    }

    public func startWork(message: Message? = nil) async throws {
        try await updateStatus(.working, message: message)
    }

    public func complete(message: Message? = nil) async throws {
        try await updateStatus(.completed, message: message)
    }

    public func fail(message: Message? = nil) async throws {
        try await updateStatus(.failed, message: message)
    }

    public func reject(message: Message? = nil) async throws {
        try await updateStatus(.rejected, message: message)
    }

    public func cancel(message: Message? = nil) async throws {
        try await updateStatus(.canceled, message: message)
    }

    public func requiresInput(message: Message? = nil) async throws {
        try await updateStatus(.inputRequired, message: message)
    }

    public func requiresAuth(message: Message? = nil) async throws {
        try await updateStatus(.authRequired, message: message)
    }
}

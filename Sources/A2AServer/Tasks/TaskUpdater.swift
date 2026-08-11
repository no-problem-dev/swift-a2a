import A2ACore
import Foundation

/// The convenient way for an executor to publish task updates: it fills in the identifiers, stamps
/// each status with the current time, and refuses to publish anything after a terminal state.
///
/// The terminal guard is per instance, not per task. Two updaters built for the same task do not
/// know about each other, and a second one will happily publish past a state the first finished on.
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

    /// Publishes a status update, timestamped now.
    ///
    /// The message, if given, is appended to the task's history when the update is applied — which
    /// is how an agent asks a question alongside an input-required state.
    ///
    /// - Parameters:
    ///   - state: The state to move to.
    ///   - message: What to say about it.
    ///   - metadata: Extension data to carry on the event.
    /// - Throws: `A2AServerError.internalError` if this updater already published a terminal state.
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

    /// Publishes an artifact, or another piece of one already in flight.
    ///
    /// Streaming an artifact means calling this repeatedly with the same `artifactId` and
    /// `append: true`; leaving the ID to its default mints a new one each time, which produces
    /// separate artifacts rather than a growing one.
    ///
    /// Not subject to the terminal guard — publishing an artifact after a terminal state succeeds
    /// here, though nothing is left listening for it.
    ///
    /// - Parameters:
    ///   - parts: The content.
    ///   - artifactId: Which artifact this belongs to. A fresh UUID by default.
    ///   - name: A name for people to read.
    ///   - description: A description for people to read.
    ///   - append: Whether to add to the artifact already held under this ID rather than replace it.
    ///   - lastChunk: Whether this is the final piece. Recorded, but nothing acts on it.
    ///   - metadata: Extension data to carry on the event.
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

    /// Builds an agent message already tied to this task and conversation, ready to attach to a
    /// status update.
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

    /// Moves to submitted: accepted, not started.
    public func submit(message: Message? = nil) async throws {
        try await updateStatus(.submitted, message: message)
    }

    /// Moves to working.
    public func startWork(message: Message? = nil) async throws {
        try await updateStatus(.working, message: message)
    }

    /// Moves to completed. Terminal — nothing further can be published from this updater.
    public func complete(message: Message? = nil) async throws {
        try await updateStatus(.completed, message: message)
    }

    /// Moves to failed. Terminal — nothing further can be published from this updater.
    public func fail(message: Message? = nil) async throws {
        try await updateStatus(.failed, message: message)
    }

    /// Moves to rejected: the agent declines the work outright. Terminal.
    public func reject(message: Message? = nil) async throws {
        try await updateStatus(.rejected, message: message)
    }

    /// Moves to canceled. Terminal, and what a cancellation run must reach for the request to be
    /// reported as cancelled.
    public func cancel(message: Message? = nil) async throws {
        try await updateStatus(.canceled, message: message)
    }

    /// Moves to input-required and ends this run. The framework calls `execute` again with the
    /// same task when the client replies, so leave enough in the task to resume from.
    public func requiresInput(message: Message? = nil) async throws {
        try await updateStatus(.inputRequired, message: message)
    }

    /// Moves to auth-required and ends this run, to be resumed once the client authenticates.
    public func requiresAuth(message: Message? = nil) async throws {
        try await updateStatus(.authRequired, message: message)
    }
}

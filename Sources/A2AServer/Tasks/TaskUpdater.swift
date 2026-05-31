import A2ACore
import Foundation

/// `AgentExecutor` がタスク更新を publish するためのヘルパ（a2a-python `TaskUpdater`）。
///
/// `TaskStatusUpdateEvent` / `TaskArtifactUpdateEvent` の生成と enqueue を簡略化します。
/// 終端状態（completed/failed/canceled/rejected）に到達後の更新はエラーになります。
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

    /// 任意状態への遷移を publish する。
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

    /// アーティファクトを publish する。
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

    /// このタスク/コンテキストに紐づくエージェントメッセージを構築する。
    public func newAgentMessage(_ parts: [Part], metadata: A2AMetadata? = nil) -> Message {
        Message(
            messageId: MessageID(UUID().uuidString),
            role: .agent,
            parts: parts,
            contextId: contextId,
            taskId: taskId,
            metadata: metadata
        )
    }

    // MARK: - 状態遷移ショートカット（a2a-python と同じ）

    /// 受理（submitted）。
    public func submit(message: Message? = nil) async throws {
        try await updateStatus(.submitted, message: message)
    }

    /// 処理開始（working）。
    public func startWork(message: Message? = nil) async throws {
        try await updateStatus(.working, message: message)
    }

    /// 正常完了（completed）。
    public func complete(message: Message? = nil) async throws {
        try await updateStatus(.completed, message: message)
    }

    /// 失敗（failed）。
    public func failed(message: Message? = nil) async throws {
        try await updateStatus(.failed, message: message)
    }

    /// 拒否（rejected）。
    public func reject(message: Message? = nil) async throws {
        try await updateStatus(.rejected, message: message)
    }

    /// キャンセル（canceled）。
    public func cancel(message: Message? = nil) async throws {
        try await updateStatus(.canceled, message: message)
    }

    /// 入力待ち（input-required）。
    public func requiresInput(message: Message? = nil) async throws {
        try await updateStatus(.inputRequired, message: message)
    }

    /// 認証待ち（auth-required）。
    public func requiresAuth(message: Message? = nil) async throws {
        try await updateStatus(.authRequired, message: message)
    }
}

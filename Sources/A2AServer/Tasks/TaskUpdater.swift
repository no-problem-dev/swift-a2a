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

    /// タスク状態を `state` に更新し、`EventQueue` に enqueue する。
    ///
    /// 終端状態（completed/failed/canceled/rejected）到達後に再呼び出しするとエラーになる。
    /// - Parameters:
    ///   - state: 設定する `TaskState`。
    ///   - message: 状態に添付するメッセージ（省略可）。
    ///   - metadata: 拡張メタデータ（省略可）。
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

    /// アーティファクト更新イベントを生成して `EventQueue` に enqueue する。
    /// - Parameters:
    ///   - parts: アーティファクトのコンテンツパーツ。
    ///   - artifactId: アーティファクト ID（省略時は UUID 自動生成）。
    ///   - name: アーティファクト名（省略可）。
    ///   - description: 説明（省略可）。
    ///   - append: 既存アーティファクトへの追記モードにする場合 `true`。
    ///   - lastChunk: ストリーミング最終チャンクの場合 `true`。
    ///   - metadata: 拡張メタデータ（省略可）。
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

    /// 状態を `.submitted` に更新する。`updateStatus(.submitted)` の略記。
    public func submit(message: Message? = nil) async throws {
        try await updateStatus(.submitted, message: message)
    }

    /// 状態を `.working` に更新する。`updateStatus(.working)` の略記。
    public func startWork(message: Message? = nil) async throws {
        try await updateStatus(.working, message: message)
    }

    /// 状態を `.completed` に更新する（終端状態）。`updateStatus(.completed)` の略記。
    public func complete(message: Message? = nil) async throws {
        try await updateStatus(.completed, message: message)
    }

    /// 状態を `.failed` に更新する（終端状態）。`updateStatus(.failed)` の略記。
    public func fail(message: Message? = nil) async throws {
        try await updateStatus(.failed, message: message)
    }

    /// 状態を `.rejected` に更新する（終端状態）。`updateStatus(.rejected)` の略記。
    public func reject(message: Message? = nil) async throws {
        try await updateStatus(.rejected, message: message)
    }

    /// 状態を `.canceled` に更新する（終端状態）。`updateStatus(.canceled)` の略記。
    public func cancel(message: Message? = nil) async throws {
        try await updateStatus(.canceled, message: message)
    }

    /// 状態を `.inputRequired` に更新する（中断状態。入力受信後に framework が再 `execute` を呼ぶ）。
    public func requiresInput(message: Message? = nil) async throws {
        try await updateStatus(.inputRequired, message: message)
    }

    /// 状態を `.authRequired` に更新する（中断状態）。
    public func requiresAuth(message: Message? = nil) async throws {
        try await updateStatus(.authRequired, message: message)
    }
}

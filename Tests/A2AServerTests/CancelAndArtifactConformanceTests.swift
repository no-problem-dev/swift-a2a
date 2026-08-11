import Foundation
import Testing
import A2ACore
@testable import A2AServer

/// Conformance for cancellation and for artifact append semantics.
///
/// Cancelling an unknown task is not-found; cancelling one whose executor declines to reach the
/// canceled state is not-cancelable. Artifact updates carry `append` and `lastChunk` through to
/// the event unchanged.
@Suite("Cancel + artifact conformance (mirror of a2a-python)")
struct CancelAndArtifactConformanceTests {

    private func card() -> AgentCard {
        AgentCard(
            name: "w", description: "w",
            supportedInterfaces: [AgentInterface(url: "inprocess://local", protocolBinding: "InProcess")],
            version: "1.0.0", capabilities: AgentCapabilities(streaming: true)
        )
    }

    private func userMessage(_ text: String, taskId: TaskID) -> Message {
        Message(messageId: MessageID(UUID().uuidString), role: .user, parts: [.text(text)], taskId: taskId)
    }

    /// An executor that waits in working and publishes canceled when asked to stop.
    private struct Hanging: AgentExecutor {
        func execute(_ c: RequestContext, eventQueue q: EventQueue) async throws {
            let u = TaskUpdater(eventQueue: q, taskId: c.taskId, contextId: c.contextId)
            try await u.startWork()
            try await Task.sleep(for: .seconds(60))
        }
        func cancel(_ c: RequestContext, eventQueue q: EventQueue) async throws {
            let u = TaskUpdater(eventQueue: q, taskId: c.taskId, contextId: c.contextId)
            try await u.cancel()
        }
    }

    /// An executor whose cancel publishes nothing, so the task never reaches canceled.
    private struct UncancelableWorking: AgentExecutor {
        func execute(_ c: RequestContext, eventQueue q: EventQueue) async throws {
            let u = TaskUpdater(eventQueue: q, taskId: c.taskId, contextId: c.contextId)
            try await u.startWork()
            try await Task.sleep(for: .seconds(60))
        }
        func cancel(_ c: RequestContext, eventQueue q: EventQueue) async throws { /* no-op */ }
    }

    private func startWorking(_ handler: DefaultRequestHandler, _ store: InMemoryTaskStore, _ taskId: TaskID) async throws {
        Task { _ = try? await handler.onMessageSend(SendMessageRequest(message: userMessage("go", taskId: taskId), configuration: SendMessageConfiguration(returnImmediately: true)), context: ServerCallContext()) }
        for _ in 0..<200 {
            if let t = try await store.get(taskId), t.status.state == .working { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("task did not reach working")
    }

    @Test("未知タスクの cancel は TaskNotFound (-32001)")
    func cancelUnknownThrowsNotFound() async throws {
        let handler = DefaultRequestHandler(agentCard: card(), executor: Hanging(), taskStore: InMemoryTaskStore())
        do {
            _ = try await handler.onCancelTask(CancelTaskRequest(id: TaskID("nope")), context: ServerCallContext())
            Issue.record("should throw")
        } catch let e as A2AServerError {
            #expect(e.code == -32001)
        }
    }

    @Test("executor が CANCELED を発行すれば canceled が返る")
    func cancelSucceedsWhenExecutorCancels() async throws {
        let store = InMemoryTaskStore()
        let handler = DefaultRequestHandler(agentCard: card(), executor: Hanging(), taskStore: store)
        let taskId = TaskID("cancelable")
        try await startWorking(handler, store, taskId)

        let result = try await handler.onCancelTask(CancelTaskRequest(id: taskId), context: ServerCallContext())
        #expect(result?.status.state == .canceled)
        #expect(try await store.get(taskId)?.status.state == .canceled)
    }

    @Test("executor が CANCELED に遷移しなければ TaskNotCancelable (-32002)")
    func cancelFailsWhenExecutorDoesNotCancel() async throws {
        let store = InMemoryTaskStore()
        let handler = DefaultRequestHandler(agentCard: card(), executor: UncancelableWorking(), taskStore: store)
        let taskId = TaskID("stubborn")
        try await startWorking(handler, store, taskId)

        do {
            _ = try await handler.onCancelTask(CancelTaskRequest(id: taskId), context: ServerCallContext())
            Issue.record("should throw")
        } catch let e as A2AServerError {
            #expect(e.code == -32002)
        }
    }

    @Test("TaskUpdater.addArtifact は append/lastChunk をイベントに透過する", arguments: [
        (false, false), (true, true), (true, false), (false, true),
    ])
    func addArtifactPropagatesFlags(_ flags: (Bool, Bool)) async throws {
        let queue = EventQueue()
        let stream = await queue.tap()
        let updater = TaskUpdater(eventQueue: queue, taskId: TaskID("t"), contextId: ContextID("c"))

        await updater.addArtifact([.text("hi")], artifactId: ArtifactID("id1"), append: flags.0, lastChunk: flags.1)
        await queue.close()

        var captured: TaskArtifactUpdateEvent?
        for await event in stream {
            if case .artifactUpdate(let u) = event { captured = u }
        }
        let event = try #require(captured)
        #expect(event.artifact.artifactId == ArtifactID("id1"))
        #expect(event.append == flags.0)
        #expect(event.lastChunk == flags.1)
    }
}

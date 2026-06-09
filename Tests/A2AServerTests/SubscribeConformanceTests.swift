import Foundation
import Testing
import A2ACore
@testable import A2AServer

/// tasks/resubscribe（SubscribeToTask）の標準準拠テスト。
///
/// a2a-python `on_subscribe_to_task` の契約を移植: get → terminal なら UnsupportedOperation →
/// 最初のイベントは必ず Task（spec §311）→ queue 無しなら TaskNotFound。
@Suite("SubscribeToTask conformance (mirror of a2a-python on_subscribe_to_task)")
struct SubscribeConformanceTests {

    private func card() -> AgentCard {
        AgentCard(
            name: "w", description: "w",
            supportedInterfaces: [AgentInterface(url: "inprocess://local", protocolBinding: "InProcess")],
            version: "1.0.0", capabilities: AgentCapabilities(streaming: true)
        )
    }

    private struct NoopExecutor: AgentExecutor {
        func execute(_ context: RequestContext, eventQueue: EventQueue) async throws {}
        func cancel(_ context: RequestContext, eventQueue: EventQueue) async throws {}
    }

    private func handler(store: InMemoryTaskStore, queues: InMemoryQueueManager) -> DefaultRequestHandler {
        DefaultRequestHandler(agentCard: card(), executor: NoopExecutor(), taskStore: store, queueManager: queues)
    }

    @Test("存在しないタスクへの subscribe は TaskNotFound")
    func subscribeNonexistentThrowsNotFound() async throws {
        let handler = handler(store: InMemoryTaskStore(), queues: InMemoryQueueManager())
        await #expect(throws: A2AServerError.self) {
            _ = try await handler.onSubscribeToTask(SubscribeToTaskRequest(id: TaskID("missing")), context: ServerCallContext())
        }
    }

    @Test("terminal 状態のタスクへの subscribe は UnsupportedOperation (-32004)")
    func subscribeTerminalThrowsUnsupported() async throws {
        let store = InMemoryTaskStore()
        try await store.save(A2ATask(id: TaskID("t"), contextId: ContextID("c"), status: TaskStatus(state: .completed)))
        let handler = handler(store: store, queues: InMemoryQueueManager())

        do {
            _ = try await handler.onSubscribeToTask(SubscribeToTaskRequest(id: TaskID("t")), context: ServerCallContext())
            Issue.record("should have thrown")
        } catch let error as A2AServerError {
            #expect(error.code == -32004)
        }
    }

    @Test("非終端タスクへの subscribe は最初のイベントが現在の Task（spec §311）")
    func subscribeYieldsTaskFirst() async throws {
        let store = InMemoryTaskStore()
        let queues = InMemoryQueueManager()
        let taskId = TaskID("t")
        try await store.save(A2ATask(id: taskId, contextId: ContextID("c"), status: TaskStatus(state: .working)))
        _ = await queues.createOrGet(taskId) // active queue を用意
        let handler = handler(store: store, queues: queues)

        let stream = try await handler.onSubscribeToTask(SubscribeToTaskRequest(id: taskId), context: ServerCallContext())
        var first: StreamResponse?
        for try await event in stream { first = event; break }

        guard case .task(let t)? = first else { Issue.record("first event must be a Task"); return }
        #expect(t.id == taskId)
        #expect(t.status.state == .working)
    }
}

import Foundation
import Testing
import A2ACore
@testable import A2AServer

// MARK: - executors

/// 説明付き working を複数回流してから完了する（push 進捗）。
private struct ProgressExecutor: AgentExecutor {
    let steps: [String]
    func execute(_ context: RequestContext, eventQueue: EventQueue) async throws {
        let updater = TaskUpdater(eventQueue: eventQueue, taskId: context.taskId, contextId: context.contextId)
        try await updater.startWork()
        for step in steps {
            try await updater.updateStatus(.working, message: updater.newAgentMessage([.text(step)]))
        }
        await updater.addArtifact([.text("done")], name: "result")
        try await updater.complete()
    }
    func cancel(_ context: RequestContext, eventQueue: EventQueue) async throws {}
}

/// 少し時間のかかるワーカー（returnImmediately / subscribe 用）。
private struct SlowExecutor: AgentExecutor {
    func execute(_ context: RequestContext, eventQueue: EventQueue) async throws {
        let updater = TaskUpdater(eventQueue: eventQueue, taskId: context.taskId, contextId: context.contextId)
        try await updater.startWork()
        try await Task.sleep(for: .milliseconds(40))
        try await updater.updateStatus(.working, message: updater.newAgentMessage([.text("halfway")]))
        try await Task.sleep(for: .milliseconds(40))
        await updater.addArtifact([.text("slow done")], name: "result")
        try await updater.complete()
    }
    func cancel(_ context: RequestContext, eventQueue: EventQueue) async throws {}
}

private struct InstantExecutor: AgentExecutor {
    func execute(_ context: RequestContext, eventQueue: EventQueue) async throws {
        let updater = TaskUpdater(eventQueue: eventQueue, taskId: context.taskId, contextId: context.contextId)
        try await updater.complete()
    }
    func cancel(_ context: RequestContext, eventQueue: EventQueue) async throws {}
}

private func card(streaming: Bool = true) -> AgentCard {
    AgentCard(
        name: "w", description: "w",
        supportedInterfaces: [AgentInterface(url: "inprocess://local", protocolBinding: "InProcess")],
        version: "1.0.0", capabilities: AgentCapabilities(streaming: streaming)
    )
}
private func userMessage(_ text: String, taskId: TaskID) -> Message {
    Message(messageId: MessageID(UUID().uuidString), role: .user, parts: [.text(text)], taskId: taskId)
}

@Suite("Async task patterns (streaming / returnImmediately / subscribe / listTasks)")
struct AsyncTaskPatternsTests {

    // パターン1: ストリーミング進捗
    @Test("message/stream は説明付き working を順番に流す")
    func streamingProgress() async throws {
        let handler = DefaultRequestHandler(agentCard: card(), executor: ProgressExecutor(steps: ["調査開始", "資料収集", "要約"]))
        var progress: [String] = []
        var completed = false
        for try await event in try await handler.onMessageSendStream(
            SendMessageRequest(message: userMessage("go", taskId: TaskID("p1"))), context: ServerCallContext()
        ) {
            if case .statusUpdate(let u) = event {
                if u.status.state == .working, let t = u.status.message?.text, !t.isEmpty { progress.append(t) }
                if u.status.state == .completed { completed = true }
            }
        }
        #expect(progress == ["調査開始", "資料収集", "要約"])
        #expect(completed)
    }

    // パターン2: returnImmediately（非同期開始 → getTask で完了確認）
    @Test("returnImmediately は即座に非終端スナップショットを返し、背景で完了する")
    func returnImmediately() async throws {
        let store = InMemoryTaskStore()
        let handler = DefaultRequestHandler(agentCard: card(), executor: SlowExecutor(), taskStore: store)
        let taskId = TaskID("r1")

        let response = try await handler.onMessageSend(
            SendMessageRequest(message: userMessage("go", taskId: taskId),
                               configuration: SendMessageConfiguration(returnImmediately: true)),
            context: ServerCallContext()
        )
        guard case .task(let task) = response else { Issue.record("expected task"); return }
        #expect(!task.status.state.isTerminal)   // working/submitted で即返る

        var done = false
        for _ in 0..<300 {
            if let got = try await handler.onGetTask(GetTaskRequest(id: taskId), context: ServerCallContext()),
               got.status.state == .completed { done = true; break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(done)
    }

    // パターン3: subscribe（実行中タスクへ途中購読）
    @Test("subscribeToTask は実行中タスクの以降のイベントを受信し completed を見る")
    func subscribeToRunningTask() async throws {
        let handler = DefaultRequestHandler(agentCard: card(), executor: SlowExecutor())
        let taskId = TaskID("s1")

        _ = try await handler.onMessageSend(
            SendMessageRequest(message: userMessage("go", taskId: taskId),
                               configuration: SendMessageConfiguration(returnImmediately: true)),
            context: ServerCallContext()
        )

        var sawCompleted = false
        for try await event in try await handler.onSubscribeToTask(SubscribeToTaskRequest(id: taskId), context: ServerCallContext()) {
            switch event {
            case .statusUpdate(let u) where u.status.state == .completed: sawCompleted = true
            case .task(let t) where t.status.state == .completed: sawCompleted = true
            default: break
            }
        }
        #expect(sawCompleted)
    }

    // パターン4: listTasks（状況照会・pull）
    @Test("InMemoryTaskStore.list は status で絞り込める")
    func listTasksByStatusUnit() async throws {
        let store = InMemoryTaskStore()
        try await store.save(A2ATask(id: TaskID("a"), contextId: ContextID("c"), status: TaskStatus(state: .working)))
        try await store.save(A2ATask(id: TaskID("b"), contextId: ContextID("c"), status: TaskStatus(state: .completed)))
        try await store.save(A2ATask(id: TaskID("c"), contextId: ContextID("c"), status: TaskStatus(state: .working)))

        let working = try await store.list(ListTasksRequest(status: .working))
        #expect(Set(working.tasks.map(\.id)) == [TaskID("a"), TaskID("c")])
        let completed = try await store.list(ListTasksRequest(status: .completed))
        #expect(completed.tasks.map(\.id) == [TaskID("b")])
    }

    @Test("onListTasks は完了済みタスクを返す（ハンドラ経由）")
    func listTasksViaHandler() async throws {
        let store = InMemoryTaskStore()
        let handler = DefaultRequestHandler(agentCard: card(), executor: InstantExecutor(), taskStore: store)
        _ = try await handler.onMessageSend(SendMessageRequest(message: userMessage("go", taskId: TaskID("done1"))), context: ServerCallContext())

        let completed = try await handler.onListTasks(ListTasksRequest(status: .completed), context: ServerCallContext())
        #expect(completed.tasks.contains { $0.id == TaskID("done1") })
    }
}

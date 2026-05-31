import Foundation
import Testing
import A2ACore
@testable import A2AServer

/// 実行を開始（working）後、キャンセルされるまで停止しないワーカー。
/// Task キャンセルで `Task.sleep` が `CancellationError` を投げて execute が終わる。
private struct HangingExecutor: AgentExecutor {
    func execute(_ context: RequestContext, eventQueue: EventQueue) async throws {
        let updater = TaskUpdater(eventQueue: eventQueue, taskId: context.taskId, contextId: context.contextId)
        try await updater.startWork()
        try await Task.sleep(for: .seconds(60))
        try await updater.complete()
    }
    func cancel(_ context: RequestContext, eventQueue: EventQueue) async throws {
        let updater = TaskUpdater(eventQueue: eventQueue, taskId: context.taskId, contextId: context.contextId)
        try await updater.cancel()
    }
}

private func makeCard() -> AgentCard {
    AgentCard(
        name: "Hang", description: "hangs until cancelled",
        supportedInterfaces: [AgentInterface(url: "inprocess://local", protocolBinding: "InProcess")],
        version: "1.0.0", capabilities: AgentCapabilities(streaming: true)
    )
}

private func userMessage(_ text: String, taskId: TaskID) -> Message {
    Message(messageId: MessageID(UUID().uuidString), role: .user, parts: [.text(text)], taskId: taskId)
}

@Suite("Cancellation of a running task")
struct CancellationTests {

    @Test("実行中タスクを cancelTask すると producer が中断され canceled になる")
    func cancelRunningTask() async throws {
        let store = InMemoryTaskStore()
        let handler = DefaultRequestHandler(agentCard: makeCard(), executor: HangingExecutor(), taskStore: store)
        let taskId = TaskID("t1")

        // ストリーミングでワーカーを起動（working で待機）。
        let streamTask = Task {
            var sawCanceled = false
            for try await event in try await handler.onMessageSendStream(SendMessageRequest(message: userMessage("go", taskId: taskId)), context: ServerCallContext()) {
                if case .statusUpdate(let update) = event, update.status.state == .canceled {
                    sawCanceled = true
                }
            }
            return sawCanceled
        }

        // working になるまで待つ。
        var started = false
        for _ in 0..<200 {
            if let task = try await store.get(taskId), task.status.state == .working {
                started = true
                break
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(started)

        // 実行中タスクをキャンセル → producer 中断 + canceled 発行。
        let canceled = try await handler.onCancelTask(CancelTaskRequest(id: taskId), context: ServerCallContext())
        #expect(canceled?.status.state == .canceled)

        let stored = try await store.get(taskId)
        #expect(stored?.status.state == .canceled)

        _ = try? await streamTask.value
    }

    @Test("終端タスクの cancelTask は taskNotCancelable を投げる")
    func cancelTerminalTask() async throws {
        let store = InMemoryTaskStore()
        // 即完了するワーカー
        struct Done: AgentExecutor {
            func execute(_ c: RequestContext, eventQueue q: EventQueue) async throws {
                let u = TaskUpdater(eventQueue: q, taskId: c.taskId, contextId: c.contextId)
                try await u.complete()
            }
            func cancel(_ c: RequestContext, eventQueue q: EventQueue) async throws {}
        }
        let handler = DefaultRequestHandler(agentCard: makeCard(), executor: Done(), taskStore: store)
        let taskId = TaskID("t2")
        _ = try await handler.onMessageSend(SendMessageRequest(message: userMessage("go", taskId: taskId)), context: ServerCallContext())

        await #expect(throws: A2AServerError.taskNotCancelable(taskId)) {
            _ = try await handler.onCancelTask(CancelTaskRequest(id: taskId), context: ServerCallContext())
        }
    }
}

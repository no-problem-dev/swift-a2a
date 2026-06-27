import Foundation
import Testing
@testable import A2AInProcess

private struct EchoExecutor: AgentExecutor {
    func execute(_ context: RequestContext, eventQueue: EventQueue) async throws {
        let updater = TaskUpdater(eventQueue: eventQueue, taskId: context.taskId, contextId: context.contextId)
        try await updater.startWork()
        await updater.addArtifact([.text("echo: \(context.userInput())")], name: "echo")
        try await updater.complete()
    }
    func cancel(_ context: RequestContext, eventQueue: EventQueue) async throws {}
}

/// 1 ターン目で input-required、2 ターン目で completed。
private struct InputRequiredExecutor: AgentExecutor {
    func execute(_ context: RequestContext, eventQueue: EventQueue) async throws {
        let updater = TaskUpdater(eventQueue: eventQueue, taskId: context.taskId, contextId: context.contextId)
        if context.currentTask == nil {
            try await updater.startWork()
            try await updater.requiresInput(message: updater.makeAgentMessage([.text("詳細をください")]))
        } else {
            try await updater.complete()
        }
    }
    func cancel(_ context: RequestContext, eventQueue: EventQueue) async throws {}
}

private func makeCard(streaming: Bool = true) -> AgentCard {
    AgentCard(
        name: "Worker", description: "in-process worker",
        supportedInterfaces: [AgentInterface(url: "inprocess://local", protocolBinding: "InProcess")],
        version: "1.0.0",
        capabilities: AgentCapabilities(streaming: streaming)
    )
}

private func userMessage(_ text: String, taskId: TaskID? = nil, contextId: ContextID? = nil) -> Message {
    Message(messageId: MessageID(UUID().uuidString), role: .user, parts: [.text(text)], contextId: contextId, taskId: taskId)
}

@Suite("InProcessTransport")
struct InProcessTransportTests {
    @Test("A2AClient.inProcess でメッセージ送信 → completed タスク（型直結・HTTP なし）")
    func sendMessageInProcess() async throws {
        let handler = DefaultRequestHandler(agentCard: makeCard(), executor: EchoExecutor())
        let client = A2AClient.inProcess(handler: handler)

        let response = try await client.sendMessage(userMessage("hello"))
        guard case .task(let task) = response else { Issue.record("expected task"); return }
        #expect(task.status.state == .completed)
        #expect(task.artifacts.first?.parts.first?.text == "echo: hello")
    }

    @Test("streamMessage で submitted/working/completed が型のまま流れる")
    func streamInProcess() async throws {
        let handler = DefaultRequestHandler(agentCard: makeCard(), executor: EchoExecutor())
        let client = A2AClient.inProcess(handler: handler)

        var states: [TaskState] = []
        for try await event in try await client.streamMessage(userMessage("hi")) {
            if case .statusUpdate(let update) = event { states.append(update.status.state) }
        }
        #expect(states == [.working, .completed])
    }

    @Test("input-required → 同一タスクへ再送 → completed（同一プロセス双方向）")
    func inputRequiredResume() async throws {
        let handler = DefaultRequestHandler(agentCard: makeCard(), executor: InputRequiredExecutor())
        let client = A2AClient.inProcess(handler: handler)

        let first = try await client.sendMessage(userMessage("start"))
        guard case .task(let task1) = first else { Issue.record("expected task"); return }
        #expect(task1.status.state == .inputRequired)

        let second = try await client.sendMessage(
            userMessage("詳細です", taskId: task1.id, contextId: task1.contextId)
        )
        guard case .task(let task2) = second else { Issue.record("expected task"); return }
        #expect(task2.id == task1.id)
        #expect(task2.status.state == .completed)
    }

    @Test("存在しないタスクの getTask はリモートと同じ A2AError.rpc(-32001) を投げる")
    func getTaskNotFoundMapsToRPCError() async throws {
        let handler = DefaultRequestHandler(agentCard: makeCard(), executor: EchoExecutor())
        let client = A2AClient.inProcess(handler: handler)

        await #expect(throws: A2AError.self) {
            _ = try await client.getTask(TaskID("missing"))
        }
        do {
            _ = try await client.getTask(TaskID("missing"))
            Issue.record("expected throw")
        } catch let A2AError.rpc(remote) {
            #expect(remote.code == -32001)
        }
    }
}

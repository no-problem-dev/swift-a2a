import Foundation
import Testing
import A2ACore
@testable import A2AServer

/// Turns the user's input into an artifact and completes.
struct EchoExecutor: AgentExecutor {
    func execute(_ context: RequestContext, eventQueue: EventQueue) async throws {
        let updater = TaskUpdater(eventQueue: eventQueue, taskId: context.taskId, contextId: context.contextId)
        try await updater.submit()
        try await updater.startWork()
        await updater.addArtifact([.text("echo: \(context.userInput())")], name: "echo")
        try await updater.complete()
    }

    func cancel(_ context: RequestContext, eventQueue: EventQueue) async throws {
        let updater = TaskUpdater(eventQueue: eventQueue, taskId: context.taskId, contextId: context.contextId)
        try await updater.cancel()
    }
}

/// Stops for input on the first run, completes on the second.
struct InputRequiredExecutor: AgentExecutor {
    func execute(_ context: RequestContext, eventQueue: EventQueue) async throws {
        let updater = TaskUpdater(eventQueue: eventQueue, taskId: context.taskId, contextId: context.contextId)
        if context.currentTask == nil {
            try await updater.startWork()
            try await updater.requiresInput(message: updater.makeAgentMessage([.text("もっと情報が必要です")]))
        } else {
            try await updater.complete(message: updater.makeAgentMessage([.text("完了しました")]))
        }
    }

    func cancel(_ context: RequestContext, eventQueue: EventQueue) async throws {}
}

private func makeCard(streaming: Bool = true) -> AgentCard {
    AgentCard(
        name: "Test Agent",
        description: "test",
        supportedInterfaces: [AgentInterface(url: "http://localhost", protocolBinding: "JSONRPC")],
        version: "1.0.0",
        capabilities: AgentCapabilities(streaming: streaming)
    )
}

private func userMessage(_ text: String, taskId: TaskID? = nil, contextId: ContextID? = nil) -> Message {
    Message(messageId: MessageID(UUID().uuidString), role: .user, parts: [.text(text)], contextId: contextId, taskId: taskId)
}

@Suite("DefaultRequestHandler")
struct DefaultRequestHandlerTests {
    @Test("message/send で completed タスクと artifact が返る")
    func messageSendCompletes() async throws {
        let store = InMemoryTaskStore()
        let handler = DefaultRequestHandler(agentCard: makeCard(), executor: EchoExecutor(), taskStore: store)

        let response = try await handler.onMessageSend(
            SendMessageRequest(message: userMessage("hello")),
            context: ServerCallContext()
        )

        guard case .task(let task) = response else {
            Issue.record("expected task, got \(response)")
            return
        }
        #expect(task.status.state == .completed)
        #expect(task.artifacts.count == 1)
        #expect(task.artifacts.first?.parts.first?.text == "echo: hello")

        let stored = try await store.get(task.id)
        #expect(stored?.status.state == .completed)
    }

    @Test("message/stream で submitted→working→completed と artifact が流れる")
    func messageStreamYieldsEvents() async throws {
        let handler = DefaultRequestHandler(agentCard: makeCard(), executor: EchoExecutor())

        let stream = try await handler.onMessageSendStream(
            SendMessageRequest(message: userMessage("hi")),
            context: ServerCallContext()
        )

        var states: [TaskState] = []
        var artifactCount = 0
        for try await event in stream {
            switch event {
            case .statusUpdate(let update): states.append(update.status.state)
            case .artifactUpdate: artifactCount += 1
            default: break
            }
        }
        #expect(states == [.submitted, .working, .completed])
        #expect(artifactCount == 1)
    }

    @Test("input-required で中断し、同一タスクへの再送で completed になる")
    func inputRequiredResumes() async throws {
        let store = InMemoryTaskStore()
        let handler = DefaultRequestHandler(agentCard: makeCard(), executor: InputRequiredExecutor(), taskStore: store)

        let first = try await handler.onMessageSend(
            SendMessageRequest(message: userMessage("start")),
            context: ServerCallContext()
        )
        guard case .task(let task1) = first else {
            Issue.record("expected task")
            return
        }
        #expect(task1.status.state == .inputRequired)

        let second = try await handler.onMessageSend(
            SendMessageRequest(message: userMessage("more info", taskId: task1.id, contextId: task1.contextId)),
            context: ServerCallContext()
        )
        guard case .task(let task2) = second else {
            Issue.record("expected task")
            return
        }
        #expect(task2.id == task1.id)
        #expect(task2.status.state == .completed)
    }

    @Test("tasks/get で保存済みタスクを取得できる")
    func getTask() async throws {
        let store = InMemoryTaskStore()
        let handler = DefaultRequestHandler(agentCard: makeCard(), executor: EchoExecutor(), taskStore: store)
        let response = try await handler.onMessageSend(
            SendMessageRequest(message: userMessage("hello")),
            context: ServerCallContext()
        )
        guard case .task(let task) = response else { Issue.record("expected task"); return }

        let fetched = try await handler.onGetTask(GetTaskRequest(id: task.id), context: ServerCallContext())
        #expect(fetched?.id == task.id)
        #expect(fetched?.status.state == .completed)
    }
}

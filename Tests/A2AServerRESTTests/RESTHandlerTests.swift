import Foundation
import Testing
import A2ACore
import A2AServer
@testable import A2AServerREST

private struct EchoExecutor: AgentExecutor {
    func execute(_ context: RequestContext, eventQueue: EventQueue) async throws {
        let updater = TaskUpdater(eventQueue: eventQueue, taskId: context.taskId, contextId: context.contextId)
        try await updater.startWork()
        await updater.addArtifact([.text("echo: \(context.userInput())")], name: "echo")
        try await updater.complete()
    }
    func cancel(_ context: RequestContext, eventQueue: EventQueue) async throws {}
}

private struct RESTErrorOut: Decodable {
    let error: Body
    struct Body: Decodable { let code: Int; let message: String }
}

private func makeCard(streaming: Bool = true) -> AgentCard {
    AgentCard(
        name: "Test", description: "t",
        supportedInterfaces: [AgentInterface(url: "http://localhost", protocolBinding: "HTTP+JSON")],
        version: "1.0.0",
        capabilities: AgentCapabilities(streaming: streaming)
    )
}

private func makeHandler(streaming: Bool = true) -> RESTHandler {
    RESTHandler(handler: DefaultRequestHandler(agentCard: makeCard(streaming: streaming), executor: EchoExecutor()))
}

private func userMessage(_ text: String) -> Message {
    Message(messageId: MessageID(UUID().uuidString), role: .user, parts: [.text(text)])
}

@Suite("RESTHandler")
struct RESTHandlerTests {
    let encoder = A2AJSON.makeEncoder()
    let decoder = A2AJSON.makeDecoder()

    @Test("POST /message:send は封筒なしの completed タスクを 200 で返す")
    func messageSend() async throws {
        let handler = makeHandler()
        let body = try encoder.encode(SendMessageRequest(message: userMessage("hi")))
        let outcome = await handler.handle(RESTRequest(method: "POST", path: "/message:send", body: body))

        guard case .response(let response) = outcome else { Issue.record("expected response"); return }
        #expect(response.status == 200)
        let result = try decoder.decode(SendMessageResponse.self, from: response.body)
        guard case .task(let task) = result else { Issue.record("expected task"); return }
        #expect(task.status.state == .completed)
        #expect(task.artifacts.first?.parts.first?.text == "echo: hi")
    }

    @Test("POST /message:stream は封筒なしの StreamResponse を流す")
    func messageStream() async throws {
        let handler = makeHandler()
        let body = try encoder.encode(SendMessageRequest(message: userMessage("hi")))
        guard case .stream(let stream) = await handler.handle(RESTRequest(method: "POST", path: "/message:stream", body: body)) else {
            Issue.record("expected stream"); return
        }
        var states: [TaskState] = []
        for try await data in stream {
            let event = try decoder.decode(StreamResponse.self, from: data)
            if case .statusUpdate(let update) = event { states.append(update.status.state) }
        }
        #expect(states.contains(.working))
        #expect(states.contains(.completed))
    }

    @Test("GET /tasks/{id} で送信済みタスクを取得し、欠落時は 404")
    func getTask() async throws {
        let handler = makeHandler()
        let body = try encoder.encode(SendMessageRequest(message: userMessage("hi")))
        guard case .response(let sent) = await handler.handle(RESTRequest(method: "POST", path: "/message:send", body: body)),
              case .task(let task) = try decoder.decode(SendMessageResponse.self, from: sent.body) else {
            Issue.record("send failed"); return
        }

        guard case .response(let got) = await handler.handle(RESTRequest(method: "GET", path: "/tasks/\(task.id.rawValue)")) else {
            Issue.record("expected response"); return
        }
        #expect(got.status == 200)
        let fetched = try decoder.decode(A2ATask.self, from: got.body)
        #expect(fetched.id == task.id)

        guard case .response(let missing) = await handler.handle(RESTRequest(method: "GET", path: "/tasks/nope")) else {
            Issue.record("expected response"); return
        }
        #expect(missing.status == 404)
        let error = try decoder.decode(RESTErrorOut.self, from: missing.body)
        #expect(error.error.code == -32001)
    }

    @Test("未対応のルートは 404 を返す")
    func unknownRoute() async throws {
        let handler = makeHandler()
        guard case .response(let response) = await handler.handle(RESTRequest(method: "GET", path: "/unknown")) else {
            Issue.record("expected response"); return
        }
        #expect(response.status == 404)
    }

    /// Every query parameter the dispatcher parses, with a value it cannot read.
    ///
    /// None of these may be dropped. A value the server does not understand has to come back as
    /// invalid params — silently ignoring it answers 200 for a request that was never honoured.
    static let unreadableQueries: [(path: String, query: [String: String])] = [
        ("/tasks", ["status": "RUNNING"]),
        ("/tasks", ["pageSize": "many"]),
        ("/tasks", ["historyLength": "1.5"]),
        ("/tasks", ["statusTimestampAfter": "2026-08-11"]),
        ("/tasks", ["includeArtifacts": "yes"]),
        ("/tasks/t1", ["historyLength": "all"]),
        ("/tasks/t1/pushNotificationConfigs", ["pageSize": ""]),
    ]

    @Test("読めないクエリ値は黙って捨てず 400 invalid params", arguments: unreadableQueries)
    func unreadableQueryValueIsRejected(_ c: (path: String, query: [String: String])) async throws {
        let handler = makeHandler()
        guard case .response(let response) = await handler.handle(
            RESTRequest(method: "GET", path: c.path, query: c.query)
        ) else { Issue.record("expected response"); return }

        #expect(response.status == 400)
        let error = try decoder.decode(RESTErrorOut.self, from: response.body)
        #expect(error.error.code == -32602)
    }

    @Test("プッシュ通知未対応エージェントでの設定作成は 501")
    func pushUnsupported() async throws {
        let handler = makeHandler()
        let config = TaskPushNotificationConfig(url: "https://example.com/hook", taskId: TaskID("t1"))
        let body = try encoder.encode(config)
        guard case .response(let response) = await handler.handle(
            RESTRequest(method: "POST", path: "/tasks/t1/pushNotificationConfigs", body: body)
        ) else { Issue.record("expected response"); return }
        #expect(response.status == 501)
        let error = try decoder.decode(RESTErrorOut.self, from: response.body)
        #expect(error.error.code == -32003)
    }
}

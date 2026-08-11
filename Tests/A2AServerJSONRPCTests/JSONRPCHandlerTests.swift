import Foundation
import Testing
import A2ACore
import A2AServer
@testable import A2AServerJSONRPC

// MARK: - Test executor

private struct EchoExecutor: AgentExecutor {
    func execute(_ context: RequestContext, eventQueue: EventQueue) async throws {
        let updater = TaskUpdater(eventQueue: eventQueue, taskId: context.taskId, contextId: context.contextId)
        try await updater.startWork()
        await updater.addArtifact([.text("echo: \(context.userInput())")], name: "echo")
        try await updater.complete()
    }
    func cancel(_ context: RequestContext, eventQueue: EventQueue) async throws {}
}

// MARK: - JSON-RPC envelopes for the test, matching what a client sends

private struct RPCRequest<P: Encodable>: Encodable {
    let jsonrpc = "2.0"
    let id: String
    let method: String
    let params: P
}

private struct RPCResult<R: Decodable>: Decodable {
    let jsonrpc: String?
    let id: String?
    let result: R?
    let error: RPCError?
}

private struct RPCError: Decodable {
    let code: Int
    let message: String
}

private func makeCard(streaming: Bool = true) -> AgentCard {
    AgentCard(
        name: "Test", description: "t",
        supportedInterfaces: [AgentInterface(url: "http://localhost", protocolBinding: "JSONRPC")],
        version: "1.0.0",
        capabilities: AgentCapabilities(streaming: streaming)
    )
}

private func makeHandler(streaming: Bool = true) -> JSONRPCHandler {
    let request = DefaultRequestHandler(agentCard: makeCard(streaming: streaming), executor: EchoExecutor())
    return JSONRPCHandler(handler: request)
}

private func userMessage(_ text: String) -> Message {
    Message(messageId: MessageID(UUID().uuidString), role: .user, parts: [.text(text)])
}

private func encodeRequest<P: Encodable>(_ method: String, _ params: P, id: String = "1") throws -> Data {
    try A2AJSON.makeEncoder().encode(RPCRequest(id: id, method: method, params: params))
}

@Suite("JSONRPCHandler")
struct JSONRPCHandlerTests {
    let decoder = A2AJSON.makeDecoder()

    @Test("SendMessage は enveloped な completed タスクを返し id をエコーする")
    func sendMessage() async throws {
        let handler = makeHandler()
        let data = try encodeRequest("SendMessage", SendMessageRequest(message: userMessage("hi")))

        let outcome = await handler.handle(data)
        guard case .unary(let responseData) = outcome else {
            Issue.record("expected unary"); return
        }
        let response = try decoder.decode(RPCResult<SendMessageResponse>.self, from: responseData)
        #expect(response.id == "1")
        #expect(response.error == nil)
        guard case .task(let task) = response.result else {
            Issue.record("expected task result"); return
        }
        #expect(task.status.state == .completed)
        #expect(task.artifacts.first?.parts.first?.text == "echo: hi")
    }

    @Test("未知メソッドは -32601 を返す")
    func methodNotFound() async throws {
        let handler = makeHandler()
        let data = try encodeRequest("DoesNotExist", SendMessageRequest(message: userMessage("x")))

        guard case .unary(let responseData) = await handler.handle(data) else {
            Issue.record("expected unary"); return
        }
        let response = try decoder.decode(RPCResult<SendMessageResponse>.self, from: responseData)
        #expect(response.error?.code == -32601)
    }

    @Test("不正な JSON は -32700 (parse error) を返す")
    func parseError() async throws {
        let handler = makeHandler()
        guard case .unary(let responseData) = await handler.handle(Data("not json".utf8)) else {
            Issue.record("expected unary"); return
        }
        let response = try decoder.decode(RPCResult<SendMessageResponse>.self, from: responseData)
        #expect(response.error?.code == -32700)
    }

    @Test("存在しないタスクの GetTask は -32001 (task not found) を返す")
    func getTaskNotFound() async throws {
        let handler = makeHandler()
        let data = try encodeRequest("GetTask", GetTaskRequest(id: TaskID("missing")))

        guard case .unary(let responseData) = await handler.handle(data) else {
            Issue.record("expected unary"); return
        }
        let response = try decoder.decode(RPCResult<A2ATask>.self, from: responseData)
        #expect(response.error?.code == -32001)
    }

    @Test("SendStreamingMessage は enveloped イベント列を流し、各 id をエコーする")
    func sendStreamingMessage() async throws {
        let handler = makeHandler()
        let data = try encodeRequest("SendStreamingMessage", SendMessageRequest(message: userMessage("hi")), id: "42")

        guard case .stream(let stream) = await handler.handle(data) else {
            Issue.record("expected stream"); return
        }

        var states: [TaskState] = []
        var ids: Set<String> = []
        for try await eventData in stream {
            let response = try decoder.decode(RPCResult<StreamResponse>.self, from: eventData)
            if let id = response.id { ids.insert(id) }
            if case .statusUpdate(let update)? = response.result {
                states.append(update.status.state)
            }
        }
        #expect(states.contains(.working))
        #expect(states.contains(.completed))
        #expect(ids == ["42"])
    }

    @Test("ストリーミング非対応エージェントへの SendStreamingMessage はエラー封筒を返す")
    func streamingUnsupported() async throws {
        let handler = makeHandler(streaming: false)
        let data = try encodeRequest("SendStreamingMessage", SendMessageRequest(message: userMessage("hi")))

        guard case .stream(let stream) = await handler.handle(data) else {
            Issue.record("expected stream"); return
        }
        var errorCode: Int?
        for try await eventData in stream {
            let response = try decoder.decode(RPCResult<StreamResponse>.self, from: eventData)
            if let error = response.error { errorCode = error.code }
        }
        #expect(errorCode == -32004) // unsupportedOperation
    }
}

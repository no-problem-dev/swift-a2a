import Foundation
import Testing
import StructuredDataCore
import A2ACore
import A2AClientCore
@testable import A2AClientJSONRPC

@Suite("JSON-RPC binding", .serialized)
struct JSONRPCTransportTests {
    let endpoint = URL(string: "https://agent.example.com/rpc")!

    func makeTransport() -> JSONRPCTransport {
        let config = A2AClientConfiguration(baseURL: endpoint)
        let http = HTTPClient(configuration: config, sessionConfiguration: MockURLProtocol.sessionConfiguration())
        return JSONRPCTransport(http: http, endpoint: endpoint)
    }

    @Test func sendMessageUsesEnvelopeAndPascalCaseMethod() async throws {
        let captured = Box<URLRequest?>(nil)
        MockURLProtocol.handler = { request in
            captured.value = request
            let body = #"{"jsonrpc":"2.0","id":"1","result":{"task":{"id":"t","status":{"state":"TASK_STATE_COMPLETED"}}}}"#
            return (makeResponse(request.url!), Data(body.utf8))
        }

        let response = try await makeTransport().sendMessage(
            SendMessageRequest(message: .user("hello"))
        )
        guard case .task(let task) = response else { Issue.record("expected task"); return }
        #expect(task.id == "t")
        #expect(task.status.state == .completed)

        // リクエスト封筒の検証
        let request = captured.value!
        #expect(request.httpMethod == "POST")
        #expect(request.url == endpoint)
        let json = try A2AJSON.makeDecoder().decode(EnvelopeProbe.self, from: request.capturedBody!)
        #expect(json.jsonrpc == "2.0")
        #expect(json.method == "SendMessage")
        #expect(json.params.message.text == "hello")
        #expect(request.value(forHTTPHeaderField: "A2A-Version") == "1.0.1")
    }

    @Test func rpcErrorIsParsed() async throws {
        MockURLProtocol.handler = { request in
            let body = """
            {"jsonrpc":"2.0","id":"1","error":{"code":-32001,"message":"Task not found",
            "data":[{"@type":"type.googleapis.com/google.rpc.ErrorInfo","reason":"TASK_NOT_FOUND","domain":"a2a-protocol.org"}]}}
            """
            return (makeResponse(request.url!), Data(body.utf8))
        }

        await #expect(throws: A2AError.self) {
            _ = try await makeTransport().getTask(GetTaskRequest(id: "missing"))
        }
        do {
            _ = try await makeTransport().getTask(GetTaskRequest(id: "missing"))
        } catch let A2AError.rpc(error) {
            #expect(error.code == A2ARemoteError.taskNotFound)
            #expect(error.reason == "TASK_NOT_FOUND")
        }
    }

    @Test func streamingDecodesEnvelopedStreamResponses() async throws {
        MockURLProtocol.handler = { request in
            let sse = """
            data: {"jsonrpc":"2.0","id":"1","result":{"task":{"id":"t","status":{"state":"TASK_STATE_WORKING"}}}}

            data: {"jsonrpc":"2.0","id":"1","result":{"statusUpdate":{"taskId":"t","contextId":"c","status":{"state":"TASK_STATE_COMPLETED"}}}}

            """
            return (makeResponse(request.url!, contentType: "text/event-stream"), Data(sse.utf8))
        }

        var events: [StreamResponse] = []
        for try await event in try await makeTransport().sendStreamingMessage(SendMessageRequest(message: .user("go"))) {
            events.append(event)
        }
        #expect(events.count == 2)
        guard case .task = events.first, case .statusUpdate(let update) = events.last else {
            Issue.record("unexpected stream events"); return
        }
        #expect(update.contextId == "c")
    }
}

/// 封筒検証用の最小デコード型。
private struct EnvelopeProbe: Decodable {
    let jsonrpc: String
    let method: String
    let params: SendMessageRequest
}

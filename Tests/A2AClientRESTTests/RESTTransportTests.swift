import Foundation
import Testing
import A2ACore
import A2AClientCore
@testable import A2AClientREST

@Suite("REST binding", .serialized)
struct RESTTransportTests {
    let baseURL = URL(string: "https://agent.example.com/a2a/v1")!

    func makeTransport() -> RESTTransport {
        let config = A2AClientConfiguration(baseURL: baseURL)
        let http = HTTPClient(configuration: config, sessionConfiguration: MockURLProtocol.sessionConfiguration())
        return RESTTransport(http: http, baseURL: baseURL)
    }

    func makeClient(baseURL: URL) -> A2AClient {
        let config = A2AClientConfiguration(baseURL: baseURL)
        let http = HTTPClient(configuration: config, sessionConfiguration: MockURLProtocol.sessionConfiguration())
        return A2AClient(transport: RESTTransport(http: http, baseURL: baseURL), http: http, configuration: config)
    }

    /// The smallest card that decodes, in the wire form the reference fixture uses.
    static let validAgentCard = """
    {
      "name": "TestAgent",
      "description": "A test agent",
      "version": "1.0.0",
      "supportedInterfaces": [{"url": "https://example.com/a2a", "protocolBinding": "HTTP+JSON"}],
      "capabilities": {},
      "defaultInputModes": ["text/plain"],
      "defaultOutputModes": ["text/plain"],
      "skills": [{"id": "test-skill", "name": "Test Skill", "description": "A skill for testing", "tags": ["test"]}]
    }
    """

    @Test func sendMessagePostsToResourceURLWithoutEnvelope() async throws {
        let captured = Box<URLRequest?>(nil)
        MockURLProtocol.handler = { request in
            captured.value = request
            // No envelope in this binding: the body is the result itself.
            let body = #"{"task":{"id":"t","contextId":"c","status":{"state":"TASK_STATE_COMPLETED"}}}"#
            return (makeResponse(request.url!), Data(body.utf8))
        }

        let response = try await makeTransport().sendMessage(SendMessageRequest(message: .user("hi")))
        guard case .task(let task) = response else { Issue.record("expected task"); return }
        #expect(task.id == "t")

        let request = captured.value!
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://agent.example.com/a2a/v1/message:send")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/a2a+json")
    }

    @Test func getTaskUsesPathAndQuery() async throws {
        let captured = Box<URLRequest?>(nil)
        MockURLProtocol.handler = { request in
            captured.value = request
            let body = #"{"id":"task-1","status":{"state":"TASK_STATE_WORKING"}}"#
            return (makeResponse(request.url!), Data(body.utf8))
        }

        let task = try await makeTransport().getTask(GetTaskRequest(id: "task-1", historyLength: 10))
        #expect(task.id == "task-1")

        let request = captured.value!
        #expect(request.httpMethod == "GET")
        #expect(request.url?.path == "/a2a/v1/tasks/task-1")
        #expect(request.url?.query == "historyLength=10")
    }

    @Test func cancelTaskUsesColonVerb() async throws {
        let captured = Box<URLRequest?>(nil)
        MockURLProtocol.handler = { request in
            captured.value = request
            return (makeResponse(request.url!), Data(#"{"id":"t","status":{"state":"TASK_STATE_CANCELED"}}"#.utf8))
        }
        let task = try await makeTransport().cancelTask(CancelTaskRequest(id: "t"))
        #expect(task.status.state == .canceled)
        #expect(captured.value?.url?.absoluteString == "https://agent.example.com/a2a/v1/tasks/t:cancel")
    }

    @Test func errorBodyMapsToRemoteError() async throws {
        MockURLProtocol.handler = { request in
            let body = """
            {"error":{"code":404,"status":"NOT_FOUND","message":"missing",
            "details":[{"@type":"type.googleapis.com/google.rpc.ErrorInfo","reason":"TASK_NOT_FOUND","domain":"a2a-protocol.org"}]}}
            """
            return (makeResponse(request.url!, status: 404), Data(body.utf8))
        }
        do {
            _ = try await makeTransport().getTask(GetTaskRequest(id: "missing"))
            Issue.record("expected throw")
        } catch let A2AError.rpc(error) {
            #expect(error.code == 404)
            #expect(error.reason == "TASK_NOT_FOUND")
        }
    }

    // MARK: - Agent card lookup (ported from the reference implementation)

    @Test func fetchAgentCardSuccessDefaultPath() async throws {
        let captured = Box<URLRequest?>(nil)
        MockURLProtocol.handler = { request in
            captured.value = request
            return (makeResponse(request.url!, contentType: "application/json"), Data(Self.validAgentCard.utf8))
        }
        let card = try await makeClient(baseURL: URL(string: "https://example.com")!).fetchAgentCard()
        #expect(card.name == "TestAgent")
        #expect(card.skills.first?.id == "test-skill")
        #expect(captured.value?.httpMethod == "GET")
        #expect(captured.value?.url?.absoluteString == "https://example.com/.well-known/agent-card.json")
    }

    @Test func fetchAgentCardHTTPStatusError() async throws {
        MockURLProtocol.handler = { request in
            (makeResponse(request.url!, status: 404, contentType: "application/json"), Data("Not Found".utf8))
        }
        do {
            _ = try await makeClient(baseURL: URL(string: "https://example.com")!).fetchAgentCard()
            Issue.record("expected throw")
        } catch let A2AError.http(status, _) {
            #expect(status == 404)
        }
    }

    @Test func fetchAgentCardJSONDecodeError() async throws {
        MockURLProtocol.handler = { request in
            (makeResponse(request.url!, contentType: "application/json"), Data("not valid json".utf8))
        }
        do {
            _ = try await makeClient(baseURL: URL(string: "https://example.com")!).fetchAgentCard()
            Issue.record("expected throw")
        } catch let error as A2AError {
            guard case .decoding = error else { Issue.record("expected decoding error, got \(error)"); return }
        }
    }

    // Ported from the reference implementation's REST parameter round-trip test.
    @Test func listTasksBuildsCamelCaseQueryParams() async throws {
        let captured = Box<URLRequest?>(nil)
        MockURLProtocol.handler = { request in
            captured.value = request
            return (makeResponse(request.url!), Data(#"{"tasks":[],"nextPageToken":"","pageSize":10,"totalSize":0}"#.utf8))
        }

        let timestamp = Date(timeIntervalSince1970: 1_709_999_999)
        _ = try await makeTransport().listTasks(ListTasksRequest(
            contextId: "ctx-1",
            status: .working,
            pageSize: 10,
            historyLength: 5,
            statusTimestampAfter: timestamp,
            includeArtifacts: true
        ))

        let request = captured.value!
        #expect(request.url?.path == "/a2a/v1/tasks")
        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        var params: [String: String] = [:]
        for item in items { params[item.name] = item.value }
        #expect(params["contextId"] == "ctx-1")
        #expect(params["status"] == "TASK_STATE_WORKING")
        #expect(params["pageSize"] == "10")
        #expect(params["historyLength"] == "5")
        #expect(params["includeArtifacts"] == "true")
        // Timestamps are RFC 3339 and survive the round trip unchanged.
        #expect(params["statusTimestampAfter"].flatMap(RFC3339.date(from:)) == timestamp)
    }

    @Test func streamingDecodesBareStreamResponses() async throws {
        MockURLProtocol.handler = { request in
            let sse = """
            data: {"task":{"id":"t","status":{"state":"TASK_STATE_WORKING"}}}

            data: {"statusUpdate":{"taskId":"t","contextId":"c","status":{"state":"TASK_STATE_COMPLETED"}}}

            """
            return (makeResponse(request.url!, contentType: "text/event-stream"), Data(sse.utf8))
        }
        var events: [StreamResponse] = []
        for try await event in try await makeTransport().sendStreamingMessage(SendMessageRequest(message: .user("go"))) {
            events.append(event)
        }
        #expect(events.count == 2)
        guard case .statusUpdate(let update) = events.last else { Issue.record("expected statusUpdate"); return }
        #expect(update.taskId == "t")
    }
}

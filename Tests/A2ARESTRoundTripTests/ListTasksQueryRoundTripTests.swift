import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
import A2AClientREST
import A2AServer
import A2AServerREST

/// What the client puts on the wire has to be what the server can read back.
///
/// Both halves of the HTTP+JSON binding live in this package, so a query parameter the client
/// writes one way and the server parses another is a defect nothing else catches: each side's own
/// tests pass, and the mismatch only shows up as a filter that quietly matches everything. These
/// tests take the query the real ``RESTTransport`` produces and feed it to the real ``RESTHandler``
/// without touching the string in between.
@Suite("REST listTasks: client query → server parse", .serialized)
struct ListTasksQueryRoundTripTests {
    private static let older = Date(timeIntervalSince1970: 1_000)
    private static let newer = Date(timeIntervalSince1970: 3_000)
    /// Between the two, and carrying a fractional part — which is what the client always writes.
    private static let cutoff = Date(timeIntervalSince1970: 2_000.5)

    @Test("client が書いた statusTimestampAfter でサーバー側のフィルタが効く")
    func statusTimestampAfterFiltersWhatTheClientWrote() async throws {
        let query = try await clientQuery(for: ListTasksRequest(statusTimestampAfter: Self.cutoff))
        let page = try await listTasks(query: query)

        #expect(page.tasks.map(\.id.rawValue) == ["newer"])
        #expect(page.totalSize == 1)
    }

    @Test("読めない statusTimestampAfter はフィルタ無しではなく 400 invalid params")
    func malformedStatusTimestampIsRejected() async throws {
        let error = try await listTasksError(query: ["statusTimestampAfter": "yesterday"])
        #expect(error.status == 400)
        #expect(error.code == -32602)
    }

    // MARK: - Client half

    /// Drives the real transport and returns the query string it built, parsed back into pairs.
    private func clientQuery(for request: ListTasksRequest) async throws -> [String: String] {
        let baseURL = URL(string: "https://agent.example.com/a2a/v1")!
        let http = HTTPClient(
            configuration: A2AClientConfiguration(baseURL: baseURL),
            sessionConfiguration: CapturingURLProtocol.sessionConfiguration()
        )
        _ = try await RESTTransport(http: http, baseURL: baseURL).listTasks(request)

        let url = try #require(CapturingURLProtocol.capturedURL.value)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    // MARK: - Server half

    /// A handler over two tasks, one on each side of ``cutoff``.
    private func makeHandler() async throws -> RESTHandler {
        let store = InMemoryTaskStore()
        try await store.save(A2ATask(id: "older", contextId: "c", status: TaskStatus(state: .completed, timestamp: Self.older)))
        try await store.save(A2ATask(id: "newer", contextId: "c", status: TaskStatus(state: .completed, timestamp: Self.newer)))
        return RESTHandler(handler: DefaultRequestHandler(
            agentCard: AgentCard(
                name: "Test", description: "t",
                supportedInterfaces: [AgentInterface(url: "http://localhost", protocolBinding: "HTTP+JSON")],
                version: "1.0.0",
                capabilities: AgentCapabilities()
            ),
            executor: SilentExecutor(),
            taskStore: store
        ))
    }

    private func listTasks(query: [String: String]) async throws -> ListTasksResponse {
        let outcome = await (try makeHandler()).handle(RESTRequest(method: "GET", path: "/tasks", query: query))
        guard case .response(let response) = outcome else {
            Issue.record("expected a response")
            return ListTasksResponse()
        }
        #expect(response.status == 200)
        return try A2AJSON.makeDecoder().decode(ListTasksResponse.self, from: response.body)
    }

    private func listTasksError(query: [String: String]) async throws -> (status: Int, code: Int) {
        let outcome = await (try makeHandler()).handle(RESTRequest(method: "GET", path: "/tasks", query: query))
        guard case .response(let response) = outcome else {
            Issue.record("expected a response")
            return (0, 0)
        }
        let body = try A2AJSON.makeDecoder().decode(ErrorBody.self, from: response.body)
        return (response.status, body.error.code)
    }
}

private struct ErrorBody: Decodable {
    let error: Detail
    struct Detail: Decodable { let code: Int; let message: String }
}

/// Does nothing: these tests list tasks that are already stored, and never run one.
private struct SilentExecutor: AgentExecutor {
    func execute(_ context: RequestContext, eventQueue: EventQueue) async throws {}
    func cancel(_ context: RequestContext, eventQueue: EventQueue) async throws {}
}

/// Intercepts `URLSession` so the client's request can be read instead of sent.
private final class CapturingURLProtocol: URLProtocol, @unchecked Sendable {
    static let capturedURL = Box<URL?>(nil)

    static func sessionConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CapturingURLProtocol.self]
        return config
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.capturedURL.value = request.url
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/a2a+json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"tasks":[],"nextPageToken":"","pageSize":50,"totalSize":0}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// A lock-guarded box, so the captured URL can cross the concurrency boundary the protocol class
/// imposes.
private final class Box<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: T
    init(_ value: T) { storage = value }
    var value: T {
        get { lock.withLock { storage } }
        set { lock.withLock { storage = newValue } }
    }
}

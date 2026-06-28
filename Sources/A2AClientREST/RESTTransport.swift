import Foundation
import A2ACore
import A2AClientCore

/// HTTP+JSON / REST バインディング（仕様 §11）。リソース URL と標準 HTTP 動詞を使い、封筒を持たない。
public struct RESTTransport: A2ATransport {
    private let http: HTTPClient
    private let baseURL: URL

    public init(http: HTTPClient, baseURL: URL) {
        self.http = http
        self.baseURL = baseURL
    }

    // MARK: - A2ATransport

    public func sendMessage(_ request: SendMessageRequest) async throws -> SendMessageResponse {
        try await post(path: "/message:send", body: request)
    }

    public func sendStreamingMessage(_ request: SendMessageRequest) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        try await stream(path: "/message:stream", body: request)
    }

    public func getTask(_ request: GetTaskRequest) async throws -> A2ATask {
        var query: [URLQueryItem] = []
        if let historyLength = request.historyLength {
            query.append(URLQueryItem(name: "historyLength", value: String(historyLength)))
        }
        return try await get(path: "/tasks/\(escape(request.id.rawValue))", query: query)
    }

    public func listTasks(_ request: ListTasksRequest) async throws -> ListTasksResponse {
        var query: [URLQueryItem] = []
        if let value = request.contextId { query.append(.init(name: "contextId", value: value.rawValue)) }
        if let value = request.status { query.append(.init(name: "status", value: value.rawValue)) }
        if let value = request.pageSize { query.append(.init(name: "pageSize", value: String(value))) }
        if let value = request.pageToken { query.append(.init(name: "pageToken", value: value)) }
        if let value = request.historyLength { query.append(.init(name: "historyLength", value: String(value))) }
        if let value = request.includeArtifacts { query.append(.init(name: "includeArtifacts", value: String(value))) }
        if let value = request.statusTimestampAfter {
            query.append(.init(name: "statusTimestampAfter", value: RFC3339.string(from: value)))
        }
        return try await get(path: "/tasks", query: query)
    }

    public func cancelTask(_ request: CancelTaskRequest) async throws -> A2ATask {
        try await post(path: "/tasks/\(escape(request.id.rawValue)):cancel", body: MetadataBody(metadata: request.metadata))
    }

    public func subscribeToTask(_ request: SubscribeToTaskRequest) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        try await stream(path: "/tasks/\(escape(request.id.rawValue)):subscribe", body: EmptyBody())
    }

    public func createTaskPushNotificationConfig(_ config: TaskPushNotificationConfig) async throws -> TaskPushNotificationConfig {
        let taskId = config.taskId?.rawValue ?? ""
        return try await post(path: "/tasks/\(escape(taskId))/pushNotificationConfigs", body: config)
    }

    public func getTaskPushNotificationConfig(_ request: GetTaskPushNotificationConfigRequest) async throws -> TaskPushNotificationConfig {
        try await get(path: "/tasks/\(escape(request.taskId.rawValue))/pushNotificationConfigs/\(escape(request.id))", query: [])
    }

    public func listTaskPushNotificationConfigs(_ request: ListTaskPushNotificationConfigsRequest) async throws -> ListTaskPushNotificationConfigsResponse {
        var query: [URLQueryItem] = []
        if let value = request.pageSize { query.append(.init(name: "pageSize", value: String(value))) }
        if let value = request.pageToken { query.append(.init(name: "pageToken", value: value)) }
        return try await get(path: "/tasks/\(escape(request.taskId.rawValue))/pushNotificationConfigs", query: query)
    }

    public func deleteTaskPushNotificationConfig(_ request: DeleteTaskPushNotificationConfigRequest) async throws {
        let url = try makeURL(path: "/tasks/\(escape(request.taskId.rawValue))/pushNotificationConfigs/\(escape(request.id))")
        let httpRequest = http.makeRequest(url: url, method: "DELETE", accept: A2AProtocol.a2aJSONContentType)
        let (data, response) = try await http.send(httpRequest)
        guard (200...299).contains(response.statusCode) else { throw remoteError(data: data, status: response.statusCode) }
    }

    public func getExtendedAgentCard(_ request: GetExtendedAgentCardRequest) async throws -> AgentCard {
        try await get(path: "/extendedAgentCard", query: [])
    }

    // MARK: - HTTP plumbing

    private func get<R: Decodable>(path: String, query: [URLQueryItem]) async throws -> R {
        let url = try makeURL(path: path, query: query)
        let request = http.makeRequest(url: url, method: "GET", accept: A2AProtocol.a2aJSONContentType)
        let (data, response) = try await http.send(request)
        return try decode(R.self, data: data, status: response.statusCode)
    }

    private func post<Body: Encodable, R: Decodable>(path: String, body: Body) async throws -> R {
        let url = try makeURL(path: path)
        let encoded: Data
        do { encoded = try A2AJSON.makeEncoder().encode(body) } catch { throw A2AError.encoding(error) }
        let request = http.makeRequest(
            url: url, method: "POST",
            contentType: A2AProtocol.a2aJSONContentType, accept: A2AProtocol.a2aJSONContentType,
            body: encoded
        )
        let (data, response) = try await http.send(request)
        return try decode(R.self, data: data, status: response.statusCode)
    }

    private func stream<Body: Encodable>(path: String, body: Body) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        let url = try makeURL(path: path)
        let encoded: Data
        do { encoded = try A2AJSON.makeEncoder().encode(body) } catch { throw A2AError.encoding(error) }
        let request = http.makeRequest(
            url: url, method: "POST",
            contentType: A2AProtocol.a2aJSONContentType, accept: "text/event-stream",
            body: encoded, streaming: true
        )
        let (bytes, response) = try await http.stream(request)
        guard (200...299).contains(response.statusCode) else {
            throw A2AError.http(status: response.statusCode, body: nil)
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                let decoder = A2AJSON.makeDecoder()
                do {
                    for try await event in SSEParser.events(from: bytes) {
                        // REST は封筒なし。data は StreamResponse そのもの。
                        let result = try decoder.decode(StreamResponse.self, from: Data(event.data.utf8))
                        continuation.yield(result)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func decode<R: Decodable>(_ type: R.Type, data: Data, status: Int) throws -> R {
        guard (200...299).contains(status) else { throw remoteError(data: data, status: status) }
        do {
            return try A2AJSON.makeDecoder().decode(R.self, from: data)
        } catch {
            throw A2AError.decoding(error)
        }
    }

    private func remoteError(data: Data, status: Int) -> A2AError {
        if let envelope = try? A2AJSON.makeDecoder().decode(RESTErrorEnvelope.self, from: data),
           let error = envelope.error {
            return .rpc(A2ARemoteError(
                code: error.code ?? status,
                message: error.message ?? "",
                details: error.details ?? []
            ))
        }
        return .http(status: status, body: String(data: data, encoding: .utf8))
    }

    // MARK: - URL building

    private func escape(_ component: String) -> String {
        component.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? component
    }

    private func makeURL(path: String, query: [URLQueryItem] = []) throws -> URL {
        var base = baseURL.absoluteString
        if base.hasSuffix("/") { base.removeLast() }
        guard var components = URLComponents(string: base + path) else {
            throw A2AError.invalidResponse("Cannot build URL for path \(path)")
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else {
            throw A2AError.invalidResponse("Cannot build URL for path \(path)")
        }
        return url
    }
}

// MARK: - Bodies

private struct EmptyBody: Encodable {}

private struct MetadataBody: Encodable {
    let metadata: A2AMetadata?
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }
    enum CodingKeys: String, CodingKey { case metadata }
}

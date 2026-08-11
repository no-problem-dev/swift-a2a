import Foundation
import A2ACore
import A2AClientCore
import StructuredDataCore

/// The JSON-RPC 2.0 binding (spec §9): every operation is a POST to one endpoint, and streaming
/// operations answer with Server-Sent Events whose data is one response envelope per event.
///
/// Errors carried inside an envelope become `A2AError.rpc` and keep their code; a non-2xx response
/// whose body is not an envelope becomes `A2AError.http`.
public struct JSONRPCTransport: A2ATransport {
    private let http: HTTPClient
    private let endpoint: URL

    public init(http: HTTPClient, endpoint: URL) {
        self.http = http
        self.endpoint = endpoint
    }

    /// The method names (spec §9.1), spelled to match the gRPC service methods rather than in the
    /// lowercase dotted style earlier revisions used.
    private enum Method {
        static let sendMessage = "SendMessage"
        static let sendStreamingMessage = "SendStreamingMessage"
        static let getTask = "GetTask"
        static let listTasks = "ListTasks"
        static let cancelTask = "CancelTask"
        static let subscribeToTask = "SubscribeToTask"
        static let createPushConfig = "CreateTaskPushNotificationConfig"
        static let getPushConfig = "GetTaskPushNotificationConfig"
        static let listPushConfigs = "ListTaskPushNotificationConfigs"
        static let deletePushConfig = "DeleteTaskPushNotificationConfig"
        static let extendedCard = "GetExtendedAgentCard"
    }

    // MARK: - A2ATransport

    public func sendMessage(_ request: SendMessageRequest) async throws -> SendMessageResponse {
        try await call(Method.sendMessage, request)
    }

    public func sendStreamingMessage(_ request: SendMessageRequest) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        try await stream(Method.sendStreamingMessage, request)
    }

    public func getTask(_ request: GetTaskRequest) async throws -> A2ATask {
        try await call(Method.getTask, request)
    }

    public func listTasks(_ request: ListTasksRequest) async throws -> ListTasksResponse {
        try await call(Method.listTasks, request)
    }

    public func cancelTask(_ request: CancelTaskRequest) async throws -> A2ATask {
        try await call(Method.cancelTask, request)
    }

    public func subscribeToTask(_ request: SubscribeToTaskRequest) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        try await stream(Method.subscribeToTask, request)
    }

    public func createTaskPushNotificationConfig(_ config: TaskPushNotificationConfig) async throws -> TaskPushNotificationConfig {
        try await call(Method.createPushConfig, config)
    }

    public func getTaskPushNotificationConfig(_ request: GetTaskPushNotificationConfigRequest) async throws -> TaskPushNotificationConfig {
        try await call(Method.getPushConfig, request)
    }

    public func listTaskPushNotificationConfigs(_ request: ListTaskPushNotificationConfigsRequest) async throws -> ListTaskPushNotificationConfigsResponse {
        try await call(Method.listPushConfigs, request)
    }

    public func deleteTaskPushNotificationConfig(_ request: DeleteTaskPushNotificationConfigRequest) async throws {
        try await callVoid(Method.deletePushConfig, request)
    }

    public func getExtendedAgentCard(_ request: GetExtendedAgentCardRequest) async throws -> AgentCard {
        try await call(Method.extendedCard, request)
    }

    // MARK: - RPC plumbing

    private func encodeRequest<P: Encodable>(_ method: String, _ params: P) throws -> Data {
        let envelope = JSONRPCRequest(id: UUID().uuidString, method: method, params: params)
        do {
            return try A2AJSON.makeEncoder().encode(envelope)
        } catch {
            throw A2AError.encoding(error)
        }
    }

    private func call<P: Encodable, R: Decodable>(_ method: String, _ params: P) async throws -> R {
        let body = try encodeRequest(method, params)
        let request = http.makeRequest(
            url: endpoint, method: "POST",
            contentType: A2AProtocol.jsonContentType, accept: A2AProtocol.jsonContentType,
            body: body
        )
        let (data, response) = try await http.send(request)

        let envelope: JSONRPCResponse<R>
        do {
            envelope = try A2AJSON.makeDecoder().decode(JSONRPCResponse<R>.self, from: data)
        } catch {
            if !(200...299).contains(response.statusCode) {
                throw A2AError.http(status: response.statusCode, body: String(data: data, encoding: .utf8))
            }
            throw A2AError.decoding(error)
        }
        if let error = envelope.error {
            throw A2AError.rpc(A2ARemoteError(code: error.code, message: error.message, details: error.data ?? []))
        }
        guard let result = envelope.result else { throw A2AError.emptyResult }
        return result
    }

    private func callVoid<P: Encodable>(_ method: String, _ params: P) async throws {
        let body = try encodeRequest(method, params)
        let request = http.makeRequest(
            url: endpoint, method: "POST",
            contentType: A2AProtocol.jsonContentType, accept: A2AProtocol.jsonContentType,
            body: body
        )
        let (data, response) = try await http.send(request)
        guard (200...299).contains(response.statusCode) else {
            throw A2AError.http(status: response.statusCode, body: String(data: data, encoding: .utf8))
        }
        // A void operation has no result to decode, so only the error field is inspected; a body
        // that is not an envelope at all is treated as success.
        if let envelope = try? A2AJSON.makeDecoder().decode(JSONRPCResponse<StructuredValue>.self, from: data),
           let error = envelope.error {
            throw A2AError.rpc(A2ARemoteError(code: error.code, message: error.message, details: error.data ?? []))
        }
    }

    private func stream<P: Encodable>(_ method: String, _ params: P) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        let body = try encodeRequest(method, params)
        let request = http.makeRequest(
            url: endpoint, method: "POST",
            contentType: A2AProtocol.jsonContentType, accept: "text/event-stream",
            body: body, streaming: true
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
                        let eventData = Data(event.data.utf8)
                        let envelope = try decoder.decode(JSONRPCResponse<StreamResponse>.self, from: eventData)
                        if let error = envelope.error {
                            throw A2AError.rpc(A2ARemoteError(code: error.code, message: error.message, details: error.data ?? []))
                        }
                        if let result = envelope.result {
                            continuation.yield(result)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

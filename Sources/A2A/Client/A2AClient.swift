import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - A2AClient

/// A2Aプロトコルクライアント
///
/// A2Aエージェントと通信するためのクライアントです。
/// JSON-RPC 2.0 over HTTP で通信し、SSEストリーミングもサポートします。
///
/// ## 使用例
///
/// ```swift
/// let client = A2AClient(
///     configuration: A2AClientConfiguration(
///         baseURL: URL(string: "https://agent.example.com")!,
///         authentication: .bearer("token")
///     )
/// )
///
/// let card = try await client.fetchAgentCard()
/// let result = try await client.sendMessage(.user("Hello"))
/// ```
public actor A2AClient {
    // MARK: - Properties

    private let configuration: A2AClientConfiguration
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var requestCounter: Int = 0

    // MARK: - Initialization

    /// A2Aクライアントを作成
    ///
    /// - Parameter configuration: クライアント設定
    public init(configuration: A2AClientConfiguration) {
        self.configuration = configuration

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        self.session = URLSession(configuration: sessionConfig)

        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    // MARK: - Public API

    /// エージェントカードを取得
    ///
    /// `/.well-known/agent.json` からエージェントのメタデータを取得します。
    ///
    /// - Returns: エージェントカード
    /// - Throws: `A2AError`
    public func fetchAgentCard() async throws -> AgentCard {
        let agentCardURL = configuration.baseURL
            .deletingLastPathComponent()
            .appendingPathComponent(".well-known")
            .appendingPathComponent("agent.json")

        var request = URLRequest(url: agentCardURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        configuration.authentication.apply(to: &request)

        let (data, response) = try await performRequest(request)
        try validateHTTPResponse(response, data: data)

        do {
            return try decoder.decode(AgentCard.self, from: data)
        } catch {
            throw A2AError.decodingError(underlying: error)
        }
    }

    /// メッセージを送信（同期）
    ///
    /// JSON-RPC `message/send` メソッドでメッセージを送信し、
    /// 完了まで待機して結果を返します。
    ///
    /// - Parameters:
    ///   - message: 送信するメッセージ
    ///   - configuration: 送信設定
    /// - Returns: 送信結果（タスクまたはアーティファクト）
    /// - Throws: `A2AError`
    public func sendMessage(
        _ message: Message,
        configuration: MessageSendConfiguration? = nil
    ) async throws -> A2ATask {
        let params = MessageSendParams(
            message: message,
            configuration: configuration
        )
        let result: A2ATask = try await executeRPC(
            method: .messageSend,
            params: params
        )
        return result
    }

    /// メッセージを送信（ストリーミング）
    ///
    /// JSON-RPC `message/stream` メソッドでメッセージを送信し、
    /// SSEストリームとしてイベントを受信します。
    ///
    /// - Parameters:
    ///   - message: 送信するメッセージ
    ///   - configuration: 送信設定
    /// - Returns: ストリーミングレスポンスの非同期ストリーム
    /// - Throws: `A2AError`
    public func streamMessage(
        _ message: Message,
        configuration: MessageSendConfiguration? = nil
    ) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        let params = MessageSendParams(
            message: message,
            configuration: configuration
        )
        return try await executeStreamingRPC(
            method: .messageStream,
            params: params
        )
    }

    /// タスクを取得
    ///
    /// - Parameters:
    ///   - id: タスクID
    ///   - historyLength: 取得する履歴の長さ
    /// - Returns: タスク情報
    /// - Throws: `A2AError`
    public func getTask(id: String, historyLength: Int? = nil) async throws -> A2ATask {
        let params = GetTaskParams(id: id, historyLength: historyLength)
        return try await executeRPC(method: .tasksGet, params: params)
    }

    /// タスクをキャンセル
    ///
    /// - Parameter id: タスクID
    /// - Returns: キャンセル後のタスク情報
    /// - Throws: `A2AError`
    public func cancelTask(id: String) async throws -> A2ATask {
        let params = CancelTaskParams(id: id)
        return try await executeRPC(method: .tasksCancel, params: params)
    }

    // MARK: - Internal RPC Execution

    /// JSON-RPCリクエストを実行
    private func executeRPC<P: Codable & Sendable, R: Codable & Sendable>(
        method: A2AMethod,
        params: P
    ) async throws -> R {
        let requestId = generateRequestId()
        let rpcRequest = JSONRPCRequest(
            id: requestId,
            method: method.rawValue,
            params: params
        )

        let request = try makeHTTPRequest(body: rpcRequest)
        let (data, response) = try await performRequest(request)
        try validateHTTPResponse(response, data: data)

        let rpcResponse: JSONRPCResponse<R>
        do {
            rpcResponse = try decoder.decode(JSONRPCResponse<R>.self, from: data)
        } catch {
            throw A2AError.decodingError(underlying: error)
        }

        if let error = rpcResponse.error {
            throw A2AError.rpcError(error)
        }

        guard let result = rpcResponse.result else {
            throw A2AError.emptyResult
        }

        return result
    }

    /// ストリーミングJSON-RPCリクエストを実行
    private func executeStreamingRPC<P: Codable & Sendable>(
        method: A2AMethod,
        params: P
    ) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        let requestId = generateRequestId()
        let rpcRequest = JSONRPCRequest(
            id: requestId,
            method: method.rawValue,
            params: params
        )

        var request = try makeHTTPRequest(body: rpcRequest)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = configuration.streamTimeout

        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw A2AError.httpError(statusCode: 0, body: "Not an HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // ストリーミングエラーの場合、バッファを読む
            var body = ""
            for try await line in bytes.lines {
                body += line + "\n"
                if body.count > 1024 { break }
            }
            throw A2AError.httpError(statusCode: httpResponse.statusCode, body: body)
        }

        let localDecoder = self.decoder

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let events = SSEParser.parse(lines: bytes.lines)
                    for try await event in events {
                        let eventData = Data(event.data.utf8)

                        // JSON-RPCレスポンスとしてパース
                        if let statusEvent = try? localDecoder.decode(
                            JSONRPCResponse<TaskStatusUpdateEvent>.self,
                            from: eventData
                        ), let result = statusEvent.result {
                            continuation.yield(.statusUpdate(result))
                        } else if let artifactEvent = try? localDecoder.decode(
                            JSONRPCResponse<TaskArtifactUpdateEvent>.self,
                            from: eventData
                        ), let result = artifactEvent.result {
                            continuation.yield(.artifactUpdate(result))
                        }
                        // パースできないイベントは無視
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Private Helpers

    /// HTTPリクエストを作成
    private func makeHTTPRequest<T: Encodable>(body: T) throws -> URLRequest {
        var request = URLRequest(url: configuration.baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = configuration.timeout
        configuration.authentication.apply(to: &request)

        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw A2AError.decodingError(underlying: error)
        }

        return request
    }

    /// リクエストIDを生成
    private func generateRequestId() -> JSONRPCId {
        requestCounter += 1
        return .number(requestCounter)
    }

    /// HTTPレスポンスを検証
    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw A2AError.httpError(statusCode: 0, body: "Not an HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw A2AError.httpError(statusCode: httpResponse.statusCode, body: body)
        }
    }

    /// URLSessionリクエストを実行（エラーハンドリング付き）
    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw A2AError.timeout
        } catch let error as A2AError {
            throw error
        } catch {
            throw A2AError.connectionError(underlying: error)
        }
    }
}

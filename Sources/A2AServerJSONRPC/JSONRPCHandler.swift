import A2ACore
import A2AServer
import Foundation

/// JSON-RPC リクエストの処理結果。
///
/// 単発操作は `unary`、ストリーミング操作（SendStreamingMessage / SubscribeToTask）は
/// `stream`。`stream` の各要素は 1 イベント分の JSON-RPC レスポンス封筒
/// `{jsonrpc, id, result: <StreamResponse>}`（HTTP 層が SSE フレーミングする）。
public enum JSONRPCOutcome: Sendable {
    case unary(Data)
    case stream(AsyncThrowingStream<Data, Error>)
}

/// JSON-RPC バインディングのサーバ側ディスパッチャ（a2a-python `JsonRpcDispatcher`）。
///
/// 封筒をデコードしてメソッドで分岐し、`RequestHandler` を呼び、レスポンス封筒へエンコードする。
/// HTTP フレームワークには非依存（`Data` 入出力）なので単体テスト可能。
public struct JSONRPCHandler: Sendable {
    private let handler: any RequestHandler
    private let encoder = A2AJSON.encoder()
    private let decoder = A2AJSON.decoder()

    public init(handler: any RequestHandler) {
        self.handler = handler
    }

    /// JSON-RPC メソッド名（gRPC サービスメソッドと統一。仕様 §9.1）。
    enum Method {
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

    /// リクエスト封筒を処理する。
    public func handle(_ requestData: Data, context: ServerCallContext = ServerCallContext()) async -> JSONRPCOutcome {
        guard let meta = try? decoder.decode(JSONRPCMeta.self, from: requestData) else {
            return .unary(failure(id: .null, code: A2ARPCError.parseError, message: "Parse error"))
        }
        let id = meta.id ?? .null
        guard let method = meta.method else {
            return .unary(failure(id: id, code: A2ARPCError.invalidRequest, message: "Invalid Request"))
        }

        switch method {
        case Method.sendMessage:
            return await unary(id, requestData, SendMessageRequest.self) { try await handler.onMessageSend($0, context: context) }
        case Method.getTask:
            return await unaryOptional(id, requestData, GetTaskRequest.self, notFound: { .taskNotFound($0.id) }) { try await handler.onGetTask($0, context: context) }
        case Method.listTasks:
            return await unary(id, requestData, ListTasksRequest.self) { try await handler.onListTasks($0, context: context) }
        case Method.cancelTask:
            return await unaryOptional(id, requestData, CancelTaskRequest.self, notFound: { .taskNotFound($0.id) }) { try await handler.onCancelTask($0, context: context) }
        case Method.createPushConfig:
            return await unary(id, requestData, TaskPushNotificationConfig.self) { try await handler.onCreateTaskPushNotificationConfig($0, context: context) }
        case Method.getPushConfig:
            return await unary(id, requestData, GetTaskPushNotificationConfigRequest.self) { try await handler.onGetTaskPushNotificationConfig($0, context: context) }
        case Method.listPushConfigs:
            return await unary(id, requestData, ListTaskPushNotificationConfigsRequest.self) { try await handler.onListTaskPushNotificationConfigs($0, context: context) }
        case Method.deletePushConfig:
            return await unaryVoid(id, requestData, DeleteTaskPushNotificationConfigRequest.self) { try await handler.onDeleteTaskPushNotificationConfig($0, context: context) }
        case Method.extendedCard:
            let params = decodeParams(requestData, GetExtendedAgentCardRequest.self) ?? GetExtendedAgentCardRequest()
            return await callUnary(id) { try await handler.onGetExtendedAgentCard(params, context: context) }
        case Method.sendStreamingMessage:
            guard let params = decodeParams(requestData, SendMessageRequest.self) else {
                return .unary(failure(id: id, code: A2ARPCError.invalidParams, message: "Invalid params"))
            }
            return .stream(makeStream(id) { try await handler.onMessageSendStream(params, context: context) })
        case Method.subscribeToTask:
            guard let params = decodeParams(requestData, SubscribeToTaskRequest.self) else {
                return .unary(failure(id: id, code: A2ARPCError.invalidParams, message: "Invalid params"))
            }
            return .stream(makeStream(id) { try await handler.onSubscribeToTask(params, context: context) })
        default:
            return .unary(failure(id: id, code: A2ARPCError.methodNotFound, message: "Method not found: \(method)"))
        }
    }

    // MARK: - Unary helpers

    private func unary<P: Decodable, R: Encodable>(
        _ id: JSONRPCID, _ data: Data, _ type: P.Type,
        _ call: (P) async throws -> R
    ) async -> JSONRPCOutcome {
        guard let params = decodeParams(data, type) else {
            return .unary(failure(id: id, code: A2ARPCError.invalidParams, message: "Invalid params"))
        }
        return await callUnary(id) { try await call(params) }
    }

    private func unaryOptional<P: Decodable, R: Encodable>(
        _ id: JSONRPCID, _ data: Data, _ type: P.Type,
        notFound: (P) -> A2AServerError,
        _ call: (P) async throws -> R?
    ) async -> JSONRPCOutcome {
        guard let params = decodeParams(data, type) else {
            return .unary(failure(id: id, code: A2ARPCError.invalidParams, message: "Invalid params"))
        }
        do {
            if let result = try await call(params) {
                return .unary(success(id: id, result: result))
            }
            let error = notFound(params)
            return .unary(failure(id: id, code: error.code, message: error.message))
        } catch {
            return .unary(failureMapping(id: id, error: error))
        }
    }

    private func unaryVoid<P: Decodable>(
        _ id: JSONRPCID, _ data: Data, _ type: P.Type,
        _ call: (P) async throws -> Void
    ) async -> JSONRPCOutcome {
        guard let params = decodeParams(data, type) else {
            return .unary(failure(id: id, code: A2ARPCError.invalidParams, message: "Invalid params"))
        }
        do {
            try await call(params)
            return .unary(success(id: id, result: EmptyResult()))
        } catch {
            return .unary(failureMapping(id: id, error: error))
        }
    }

    private func callUnary<R: Encodable>(_ id: JSONRPCID, _ call: () async throws -> R) async -> JSONRPCOutcome {
        do {
            return .unary(success(id: id, result: try await call()))
        } catch {
            return .unary(failureMapping(id: id, error: error))
        }
    }

    // MARK: - Stream helper

    private func makeStream(
        _ id: JSONRPCID,
        _ call: @escaping @Sendable () async throws -> AsyncThrowingStream<StreamResponse, Error>
    ) -> AsyncThrowingStream<Data, Error> {
        let encoder = self.encoder
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let events = try await call()
                    for try await event in events {
                        if let data = try? encoder.encode(JSONRPCSuccess(id: id, result: event)) {
                            continuation.yield(data)
                        }
                    }
                    continuation.finish()
                } catch {
                    let object = Self.errorObject(from: error)
                    if let data = try? encoder.encode(JSONRPCFailure(id: id, error: object)) {
                        continuation.yield(data)
                    }
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Encoding

    private func decodeParams<P: Decodable>(_ data: Data, _ type: P.Type) -> P? {
        (try? decoder.decode(JSONRPCParams<P>.self, from: data))?.params
    }

    private func success<R: Encodable>(id: JSONRPCID, result: R) -> Data {
        (try? encoder.encode(JSONRPCSuccess(id: id, result: result))) ?? Data()
    }

    private func failure(id: JSONRPCID, code: Int, message: String) -> Data {
        (try? encoder.encode(JSONRPCFailure(id: id, error: JSONRPCErrorObject(code: code, message: message)))) ?? Data()
    }

    private func failureMapping(id: JSONRPCID, error: Error) -> Data {
        let object = Self.errorObject(from: error)
        return (try? encoder.encode(JSONRPCFailure(id: id, error: object))) ?? Data()
    }

    static func errorObject(from error: Error) -> JSONRPCErrorObject {
        if let serverError = error as? A2AServerError {
            return JSONRPCErrorObject(code: serverError.code, message: serverError.message)
        }
        return JSONRPCErrorObject(code: A2ARPCError.internalError, message: "Internal error: \(error)")
    }
}

/// 標準 JSON-RPC エラーコード（仕様 §9.5）。
enum A2ARPCError {
    static let parseError = -32700
    static let invalidRequest = -32600
    static let methodNotFound = -32601
    static let invalidParams = -32602
    static let internalError = -32603
}

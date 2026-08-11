import A2ACore
import A2AServer
import Foundation

/// Routes a request by method and path to the matching handler method, per the resource mapping in
/// spec §11.
///
/// Nothing here knows about HTTP: it takes a ``RESTRequest`` and returns a ``RESTOutcome`` for the
/// server to write. Custom verbs are the `:verb` suffix on the last path segment — `:cancel`,
/// `:subscribe` — and identifiers in the path are percent-decoded.
public struct RESTHandler: Sendable {
    private let handler: any RequestHandler
    private let encoder = A2AJSON.makeEncoder()
    private let decoder = A2AJSON.makeDecoder()

    public init(handler: any RequestHandler) {
        self.handler = handler
    }

    /// Routes and dispatches one request.
    ///
    /// Never throws: every failure becomes an error response whose status comes from the A2A code.
    /// A path that matches no route answers `404` carrying the task-not-found code, whether or not
    /// the request had anything to do with a task. A body that will not decode answers `400`.
    ///
    /// A query parameter that is present but unreadable answers `400` carrying the invalid-params
    /// code. It is never dropped: a filter the server could not parse must not come back as a
    /// successful, unfiltered listing.
    ///
    /// - Parameters:
    ///   - request: The routed request.
    ///   - context: Who is calling. Defaults to an unauthenticated caller — populate it in the
    ///     HTTP layer, or every request shares one storage scope.
    public func handle(_ request: RESTRequest, context: ServerCallContext = ServerCallContext()) async -> RESTOutcome {
        let segments = request.path.split(separator: "/").map(String.init)
        let method = request.method.uppercased()

        if segments.count == 1, segments[0] == "message:send", method == "POST" {
            return await sendMessage(request.body, context)
        }
        if segments.count == 1, segments[0] == "message:stream", method == "POST" {
            return await sendStreamingMessage(request.body, context)
        }
        if segments.count == 1, segments[0] == "extendedAgentCard", method == "GET" {
            return await extendedCard(context)
        }
        if segments.count == 1, segments[0] == "tasks", method == "GET" {
            return await listTasks(request.query, context)
        }
        if segments.count == 2, segments[0] == "tasks" {
            let (rawId, verb) = splitVerb(segments[1])
            let id = TaskID(percentDecoded(rawId))
            switch (method, verb) {
            case ("GET", nil): return await getTask(id, request.query, context)
            case ("POST", "cancel"): return await cancelTask(id, request.body, context)
            case ("POST", "subscribe"): return await subscribe(id, context)
            default: return notFound()
            }
        }
        if segments.count >= 3, segments[0] == "tasks", segments[2] == "pushNotificationConfigs" {
            let taskId = TaskID(percentDecoded(segments[1]))
            if segments.count == 3 {
                switch method {
                case "POST": return await createPushConfig(taskId, request.body, context)
                case "GET": return await listPushConfigs(taskId, request.query, context)
                default: return notFound()
                }
            }
            if segments.count == 4 {
                let configId = percentDecoded(segments[3])
                switch method {
                case "GET": return await getPushConfig(taskId, configId, context)
                case "DELETE": return await deletePushConfig(taskId, configId, context)
                default: return notFound()
                }
            }
        }
        return notFound()
    }

    // MARK: - Operations

    private func sendMessage(_ body: Data, _ context: ServerCallContext) async -> RESTOutcome {
        guard let params = decode(SendMessageRequest.self, body) else { return invalidParams() }
        do {
            return ok(try await handler.onMessageSend(params, context: context))
        } catch {
            return errorResponse(error)
        }
    }

    private func sendStreamingMessage(_ body: Data, _ context: ServerCallContext) async -> RESTOutcome {
        guard let params = decode(SendMessageRequest.self, body) else { return invalidParams() }
        do {
            let events = try await handler.onMessageSendStream(params, context: context)
            return .stream(bareStream(events))
        } catch {
            return errorResponse(error)
        }
    }

    private func getTask(_ id: TaskID, _ query: [String: String], _ context: ServerCallContext) async -> RESTOutcome {
        do {
            let request = GetTaskRequest(id: id, historyLength: try RESTQuery(query).int("historyLength"))
            if let task = try await handler.onGetTask(request, context: context) {
                return ok(task)
            }
            return errorResponse(A2AServerError.taskNotFound(id))
        } catch {
            return errorResponse(error)
        }
    }

    private func listTasks(_ query: [String: String], _ context: ServerCallContext) async -> RESTOutcome {
        do {
            let query = RESTQuery(query)
            let request = ListTasksRequest(
                contextId: query.string("contextId").map(ContextID.init),
                status: try query.taskState("status"),
                pageSize: try query.int("pageSize"),
                pageToken: query.string("pageToken"),
                historyLength: try query.int("historyLength"),
                statusTimestampAfter: try query.date("statusTimestampAfter"),
                includeArtifacts: try query.bool("includeArtifacts")
            )
            return ok(try await handler.onListTasks(request, context: context))
        } catch {
            return errorResponse(error)
        }
    }

    private func cancelTask(_ id: TaskID, _ body: Data, _ context: ServerCallContext) async -> RESTOutcome {
        let metadata = (try? decoder.decode(MetadataBody.self, from: body))?.metadata
        let request = CancelTaskRequest(id: id, metadata: metadata)
        do {
            if let task = try await handler.onCancelTask(request, context: context) {
                return ok(task)
            }
            return errorResponse(A2AServerError.taskNotFound(id))
        } catch {
            return errorResponse(error)
        }
    }

    private func subscribe(_ id: TaskID, _ context: ServerCallContext) async -> RESTOutcome {
        do {
            let events = try await handler.onSubscribeToTask(SubscribeToTaskRequest(id: id), context: context)
            return .stream(bareStream(events))
        } catch {
            return errorResponse(error)
        }
    }

    private func createPushConfig(_ taskId: TaskID, _ body: Data, _ context: ServerCallContext) async -> RESTOutcome {
        guard var config = decode(TaskPushNotificationConfig.self, body) else { return invalidParams() }
        if config.taskId == nil { config.taskId = taskId }
        do {
            return ok(try await handler.onCreateTaskPushNotificationConfig(config, context: context))
        } catch {
            return errorResponse(error)
        }
    }

    private func getPushConfig(_ taskId: TaskID, _ configId: String, _ context: ServerCallContext) async -> RESTOutcome {
        do {
            let config = try await handler.onGetTaskPushNotificationConfig(
                GetTaskPushNotificationConfigRequest(taskId: taskId, id: configId), context: context)
            return ok(config)
        } catch {
            return errorResponse(error)
        }
    }

    private func listPushConfigs(_ taskId: TaskID, _ query: [String: String], _ context: ServerCallContext) async -> RESTOutcome {
        do {
            let query = RESTQuery(query)
            let request = ListTaskPushNotificationConfigsRequest(
                taskId: taskId,
                pageSize: try query.int("pageSize"),
                pageToken: query.string("pageToken")
            )
            return ok(try await handler.onListTaskPushNotificationConfigs(request, context: context))
        } catch {
            return errorResponse(error)
        }
    }

    private func deletePushConfig(_ taskId: TaskID, _ configId: String, _ context: ServerCallContext) async -> RESTOutcome {
        do {
            try await handler.onDeleteTaskPushNotificationConfig(
                DeleteTaskPushNotificationConfigRequest(taskId: taskId, id: configId), context: context)
            return .response(RESTResponse(status: 200, body: Data("{}".utf8)))
        } catch {
            return errorResponse(error)
        }
    }

    private func extendedCard(_ context: ServerCallContext) async -> RESTOutcome {
        do {
            return ok(try await handler.onGetExtendedAgentCard(GetExtendedAgentCardRequest(), context: context))
        } catch {
            return errorResponse(error)
        }
    }

    // MARK: - Helpers

    private func splitVerb(_ segment: String) -> (resource: String, verb: String?) {
        guard let colon = segment.firstIndex(of: ":") else { return (segment, nil) }
        return (String(segment[segment.startIndex..<colon]), String(segment[segment.index(after: colon)...]))
    }

    private func percentDecoded(_ value: String) -> String {
        value.removingPercentEncoding ?? value
    }

    private func decode<T: Decodable>(_ type: T.Type, _ body: Data) -> T? {
        try? decoder.decode(T.self, from: body)
    }

    private func ok<R: Encodable>(_ result: R) -> RESTOutcome {
        let body = (try? encoder.encode(result)) ?? Data()
        return .response(RESTResponse(status: 200, body: body))
    }

    private func bareStream(_ events: AsyncThrowingStream<StreamResponse, Error>) -> AsyncThrowingStream<Data, Error> {
        let encoder = self.encoder
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await event in events {
                        if let data = try? encoder.encode(event) {
                            continuation.yield(data)
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

    private func invalidParams() -> RESTOutcome {
        errorResponse(A2AServerError.invalidParams("Could not decode request body"))
    }

    private func notFound() -> RESTOutcome {
        .response(makeError(status: 404, code: A2AServerError.taskNotFound(TaskID("")).code, message: "Not found"))
    }

    private func errorResponse(_ error: Error) -> RESTOutcome {
        if let serverError = error as? A2AServerError {
            return .response(makeError(status: httpStatus(for: serverError), code: serverError.code, message: serverError.message))
        }
        return .response(makeError(status: 500, code: -32603, message: "Internal error: \(error)"))
    }

    private func makeError(status: Int, code: Int, message: String) -> RESTResponse {
        let body = (try? encoder.encode(RESTErrorResponse(error: .init(code: code, message: message)))) ?? Data()
        return RESTResponse(status: status, body: body)
    }

    private func httpStatus(for error: A2AServerError) -> Int {
        switch error {
        case .taskNotFound, .extendedAgentCardNotConfigured: 404
        case .taskNotCancelable: 409
        case .invalidParams, .contentTypeNotSupported, .extensionSupportRequired, .versionNotSupported: 400
        case .pushNotificationNotSupported, .unsupportedOperation: 501
        case .invalidAgentResponse: 502
        case .internalError: 500
        }
    }
}

/// The body of a cancel request, which carries nothing but optional metadata.
private struct MetadataBody: Decodable {
    let metadata: A2AMetadata?
}

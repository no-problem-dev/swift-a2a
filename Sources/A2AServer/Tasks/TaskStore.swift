import A2ACore
import Foundation

/// Where tasks live between requests.
///
/// Every method takes the call context because storage is partitioned by owner: a task saved under
/// one caller's scope must not be readable from another's (spec §254, §13.1). An implementation
/// that ignores the context makes every task visible to everyone.
public protocol TaskStore: Sendable {
    func save(_ task: A2ATask, context: ServerCallContext) async throws
    func get(_ id: TaskID, context: ServerCallContext) async throws -> A2ATask?
    func list(_ request: ListTasksRequest, context: ServerCallContext) async throws -> ListTasksResponse
    func delete(_ id: TaskID, context: ServerCallContext) async throws
}

/// Overloads that drop the context, standing in for an unauthenticated caller — that is, the one
/// shared scope. Convenient in tests; wrong in a deployment that serves more than one client.
public extension TaskStore {
    func save(_ task: A2ATask) async throws { try await save(task, context: ServerCallContext()) }
    func get(_ id: TaskID) async throws -> A2ATask? { try await get(id, context: ServerCallContext()) }
    func list(_ request: ListTasksRequest) async throws -> ListTasksResponse { try await list(request, context: ServerCallContext()) }
    func delete(_ id: TaskID) async throws { try await delete(id, context: ServerCallContext()) }
}

/// The page size used when a listing request does not ask for one.
public let defaultListTasksPageSize = 50
/// The largest page size the specification allows. Declared for implementations that enforce it;
/// the in-memory store honours whatever size is requested.
public let maxListTasksPageSize = 100

/// Holds tasks in a dictionary, partitioned by owner. For prototyping and tests — nothing
/// survives a restart, and nothing is shared between processes.
///
/// Listing sorts by status timestamp descending, placing tasks with no timestamp last and breaking
/// ties by task ID so the order is stable across calls. Paging is by cursor: the token is the
/// Base64 of the first task ID on the next page, and the page starts at that task inclusive. A
/// token whose task has since been removed is rejected rather than skipped.
public actor InMemoryTaskStore: TaskStore {
    private var tasksByOwner: [String: [TaskID: A2ATask]] = [:]
    private let ownerResolver: OwnerResolver

    public init() {
        self.ownerResolver = resolveUserScope
    }

    public init(ownerResolver: @escaping OwnerResolver) {
        self.ownerResolver = ownerResolver
    }

    public func save(_ task: A2ATask, context: ServerCallContext) async throws {
        tasksByOwner[ownerResolver(context), default: [:]][task.id] = task
    }

    public func get(_ id: TaskID, context: ServerCallContext) async throws -> A2ATask? {
        tasksByOwner[ownerResolver(context)]?[id]
    }

    public func list(_ request: ListTasksRequest, context: ServerCallContext) async throws -> ListTasksResponse {
        var result = Array((tasksByOwner[ownerResolver(context)] ?? [:]).values)

        // Filters combine with AND.
        if let contextId = request.contextId {
            result = result.filter { $0.contextId == contextId }
        }
        if let status = request.status {
            result = result.filter { $0.status.state == status }
        }
        if let after = request.statusTimestampAfter {
            // The bound is inclusive, and a task with no timestamp cannot satisfy it at all.
            result = result.filter { ts in ts.status.timestamp.map { $0 >= after } ?? false }
        }

        // Newest first, as the specification requires. Comparing (has timestamp, timestamp, id)
        // in descending order keeps the result stable when timestamps collide or are absent.
        result.sort { a, b in
            let at = a.status.timestamp, bt = b.status.timestamp
            if (at != nil) != (bt != nil) { return at != nil }
            if let at, let bt, at != bt { return at > bt }
            return a.id.rawValue > b.id.rawValue
        }

        // Cursor paging: the token names the first task of the page, inclusive.
        let total = result.count
        var startIdx = 0
        if let token = request.pageToken, !token.isEmpty {
            let startId = try Self.decodePageToken(token)
            guard let idx = result.firstIndex(where: { $0.id.rawValue == startId }) else {
                throw A2AServerError.invalidParams("Invalid page token: \(token)")
            }
            startIdx = idx
        }
        let pageSize = (request.pageSize ?? 0) > 0 ? request.pageSize! : defaultListTasksPageSize
        let endIdx = startIdx + pageSize
        // Empty string on the last page — the field is always present, never absent.
        let nextPageToken = endIdx < total ? Self.encodePageToken(result[endIdx].id.rawValue) : ""
        var page = Array(result[startIdx..<min(endIdx, total)])

        if request.includeArtifacts == false {
            page = page.map { var t = $0; t.artifacts = []; return t }
        }
        if let length = request.historyLength {
            page = page.map { var t = $0; t.history = Array(t.history.suffix(max(0, length))); return t }
        }

        return ListTasksResponse(tasks: page, nextPageToken: nextPageToken, pageSize: pageSize, totalSize: total)
    }

    public func delete(_ id: TaskID, context: ServerCallContext) async throws {
        tasksByOwner[ownerResolver(context)]?[id] = nil
    }

    // MARK: - Page token
    //
    // Base64 of the task ID. Opaque to clients but trivially reversible, so it must not be used to
    // carry anything a caller should not see. Decoding restores padding the encoder may have
    // dropped, so tokens from other implementations are accepted.

    static func encodePageToken(_ taskId: String) -> String {
        Data(taskId.utf8).base64EncodedString()
    }

    static func decodePageToken(_ token: String) throws -> String {
        var encoded = token
        let missingPadding = encoded.count % 4
        if missingPadding != 0 { encoded += String(repeating: "=", count: 4 - missingPadding) }
        guard let data = Data(base64Encoded: encoded), let id = String(data: data, encoding: .utf8) else {
            throw A2AServerError.invalidParams("Invalid page token: \(token)")
        }
        return id
    }
}

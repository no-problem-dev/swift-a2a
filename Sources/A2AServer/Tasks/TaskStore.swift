import A2ACore
import Foundation

/// タスクの永続化（a2a-python `TaskStore`）。
///
/// 全メソッドは `ServerCallContext` を受け取り、owner ごとにスコープ分離する（spec §254/§13.1 MUST）。
public protocol TaskStore: Sendable {
    func save(_ task: A2ATask, context: ServerCallContext) async throws
    func get(_ id: TaskID, context: ServerCallContext) async throws -> A2ATask?
    func list(_ request: ListTasksRequest, context: ServerCallContext) async throws -> ListTasksResponse
    func delete(_ id: TaskID, context: ServerCallContext) async throws
}

/// context 省略時は未認証コンテキスト（単一スコープ）として扱う利便オーバーロード。
public extension TaskStore {
    func save(_ task: A2ATask) async throws { try await save(task, context: ServerCallContext()) }
    func get(_ id: TaskID) async throws -> A2ATask? { try await get(id, context: ServerCallContext()) }
    func list(_ request: ListTasksRequest) async throws -> ListTasksResponse { try await list(request, context: ServerCallContext()) }
    func delete(_ id: TaskID) async throws { try await delete(id, context: ServerCallContext()) }
}

/// `tasks/list` の既定ページサイズ（a2a-python `DEFAULT_LIST_TASKS_PAGE_SIZE`）。
public let defaultListTasksPageSize = 50
/// `tasks/list` の最大ページサイズ（a2a-python `MAX_LIST_TASKS_PAGE_SIZE`）。
public let maxListTasksPageSize = 100

public actor InMemoryTaskStore: TaskStore {
    /// owner -> taskId -> task（a2a-python `_InMemoryTaskStoreImpl.tasks`）。
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

        // フィルタ（a2a-python InMemoryTaskStore.list と同順）。
        if let contextId = request.contextId {
            result = result.filter { $0.contextId == contextId }
        }
        if let status = request.status {
            result = result.filter { $0.status.state == status }
        }
        if let after = request.statusTimestampAfter {
            // spec: status timestamp は境界含む（>=）。timestamp 無しは除外。
            result = result.filter { ts in ts.status.timestamp.map { $0 >= after } ?? false }
        }

        // spec §262 MUST: status timestamp DESC。安定化のため (hasTimestamp, timestamp, id) を降順比較。
        result.sort { a, b in
            let at = a.status.timestamp, bt = b.status.timestamp
            if (at != nil) != (bt != nil) { return at != nil }
            if let at, let bt, at != bt { return at > bt }
            return a.id.rawValue > b.id.rawValue
        }

        // cursor ページネーション（spec §254/§258 MUST）。
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
        // spec §246 MUST: nextPageToken は常に present、終端は空文字。
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

    // MARK: - Page token (a2a-python `encode_page_token` / `decode_page_token`: base64 of task id)

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

import A2ACore
import Foundation

/// タスクの永続化（a2a-python `TaskStore`）。
public protocol TaskStore: Sendable {
    func save(_ task: A2ATask) async throws
    func get(_ id: TaskID) async throws -> A2ATask?
    func list(_ request: ListTasksRequest) async throws -> ListTasksResponse
    func delete(_ id: TaskID) async throws
}

public actor InMemoryTaskStore: TaskStore {
    private var tasks: [TaskID: A2ATask] = [:]

    public init() {}

    public func save(_ task: A2ATask) async throws {
        tasks[task.id] = task
    }

    public func get(_ id: TaskID) async throws -> A2ATask? {
        tasks[id]
    }

    public func list(_ request: ListTasksRequest) async throws -> ListTasksResponse {
        var result = Array(tasks.values)
        if let contextId = request.contextId {
            result = result.filter { $0.contextId == contextId }
        }
        if let status = request.status {
            result = result.filter { $0.status.state == status }
        }
        if let after = request.statusTimestampAfter {
            result = result.filter { ($0.status.timestamp ?? .distantPast) > after }
        }
        if request.includeArtifacts == false {
            result = result.map { var t = $0; t.artifacts = []; return t }
        }
        if let length = request.historyLength {
            result = result.map { var t = $0; t.history = Array(t.history.suffix(max(0, length))); return t }
        }
        let total = result.count
        if let pageSize = request.pageSize, pageSize > 0 {
            result = Array(result.prefix(pageSize))
        }
        return ListTasksResponse(tasks: result, pageSize: result.count, totalSize: total)
    }

    public func delete(_ id: TaskID) async throws {
        tasks[id] = nil
    }
}

import Foundation
import Testing
import A2ACore
@testable import A2AServer

/// Conformance for task listing, porting the reference implementation's parametrized cases as
/// ground truth. Covers filtering, ordering, paging and the always-present page token
/// (spec §240, §246, §254, §262).
@Suite("tasks/list conformance (mirror of a2a-python test_list_tasks)")
struct TaskListConformanceTests {

    private static let day1 = Date(timeIntervalSince1970: 1000)
    private static let day2 = Date(timeIntervalSince1970: 2000)

    /// A store seeded with the same five tasks the reference test uses.
    private func makeStore() async throws -> InMemoryTaskStore {
        let store = InMemoryTaskStore()
        let specs: [(String, String, TaskState, Date?)] = [
            ("task-0", "context-0", .submitted, Self.day1),
            ("task-1", "context-1", .working, Self.day1),
            ("task-2", "context-0", .submitted, Self.day2),
            ("task-3", "context-1", .working, nil),
            ("task-4", "context-0", .completed, nil),
        ]
        for (id, ctx, state, ts) in specs {
            try await store.save(
                A2ATask(id: TaskID(id), contextId: ContextID(ctx),
                        status: TaskStatus(state: state, timestamp: ts))
            )
        }
        return store
    }

    struct Case: Sendable {
        let request: ListTasksRequest
        let expectedIDs: [String]
        let totalSize: Int
        let nextPageToken: String
    }

    static let cases: [Case] = [
        // No filters: everything, in sort order.
        Case(request: ListTasksRequest(),
             expectedIDs: ["task-2", "task-1", "task-0", "task-4", "task-3"], totalSize: 5, nextPageToken: ""),
        // An unknown context matches nothing.
        Case(request: ListTasksRequest(contextId: "nonexistent"),
             expectedIDs: [], totalSize: 0, nextPageToken: ""),
        // Paging: the first page.
        Case(request: ListTasksRequest(pageSize: 2),
             expectedIDs: ["task-2", "task-1"], totalSize: 5, nextPageToken: "dGFzay0w"), // base64("task-0")
        // Paging across tasks sharing a timestamp.
        Case(request: ListTasksRequest(pageSize: 2, pageToken: "dGFzay0x"), // base64("task-1")
             expectedIDs: ["task-1", "task-0"], totalSize: 5, nextPageToken: "dGFzay00"), // base64("task-4")
        // Paging: the last page.
        Case(request: ListTasksRequest(pageSize: 2, pageToken: "dGFzay0z"), // base64("task-3")
             expectedIDs: ["task-3"], totalSize: 5, nextPageToken: ""),
        // Filter by context.
        Case(request: ListTasksRequest(contextId: "context-1"),
             expectedIDs: ["task-1", "task-3"], totalSize: 2, nextPageToken: ""),
        // Filter by status.
        Case(request: ListTasksRequest(status: .working),
             expectedIDs: ["task-1", "task-3"], totalSize: 2, nextPageToken: ""),
        // Filter by context and status together.
        Case(request: ListTasksRequest(contextId: "context-0", status: .submitted),
             expectedIDs: ["task-2", "task-0"], totalSize: 2, nextPageToken: ""),
        // Combined filters with paging.
        Case(request: ListTasksRequest(contextId: "context-0", pageSize: 1),
             expectedIDs: ["task-2"], totalSize: 3, nextPageToken: "dGFzay0w"), // base64("task-0")
    ]

    @Test("filters / ordering / cursor pagination", arguments: cases)
    func listTasks(_ c: Case) async throws {
        let store = try await makeStore()
        let page = try await store.list(c.request)

        #expect(page.tasks.map(\.id.rawValue) == c.expectedIDs)
        #expect(page.totalSize == c.totalSize)
        #expect((page.nextPageToken ?? "") == c.nextPageToken)
        // The reported page size is the one requested, or the default when none was.
        let expectedPageSize = (c.request.pageSize ?? 0) > 0 ? c.request.pageSize! : defaultListTasksPageSize
        #expect(page.pageSize == expectedPageSize)
    }

    @Test("invalid page token throws InvalidParams (-32602)")
    func invalidPageToken() async throws {
        let store = try await makeStore()
        await #expect(throws: A2AServerError.self) {
            _ = try await store.list(ListTasksRequest(pageToken: "@@not-base64@@"))
        }
    }

    @Test("page token round-trips as base64 of task id")
    func pageTokenRoundTrip() throws {
        #expect(InMemoryTaskStore.encodePageToken("task-0") == "dGFzay0w")
        #expect(try InMemoryTaskStore.decodePageToken("dGFzay0w") == "task-0")
    }

    @Test("nextPageToken is always present in encoded JSON (empty string on final page)")
    func nextPageTokenAlwaysEncoded() throws {
        let response = ListTasksResponse(tasks: [], nextPageToken: nil, pageSize: 50, totalSize: 0)
        let json = try JSONEncoder().encode(response)
        let object = try JSONSerialization.jsonObject(with: json) as? [String: Any]
        #expect(object?["nextPageToken"] as? String == "")
    }
}

import Foundation
import Testing
import A2ACore
@testable import A2AServer

/// `tasks/list` の標準準拠テスト。
///
/// a2a-python `tests/server/tasks/test_inmemory_task_store.py::test_list_tasks` の
/// parametrize ケースを 1:1 移植したもの（ground truth）。spec §240/§246/§254/§262。
@Suite("tasks/list conformance (mirror of a2a-python test_list_tasks)")
struct TaskListConformanceTests {

    private static let day1 = Date(timeIntervalSince1970: 1000)
    private static let day2 = Date(timeIntervalSince1970: 2000)

    /// python テストと同じ 5 タスク（task-0..4）を投入した store。
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
        // 引数なし → 全件（ソート順）
        Case(request: ListTasksRequest(),
             expectedIDs: ["task-2", "task-1", "task-0", "task-4", "task-3"], totalSize: 5, nextPageToken: ""),
        // 未知 context
        Case(request: ListTasksRequest(contextId: "nonexistent"),
             expectedIDs: [], totalSize: 0, nextPageToken: ""),
        // ページネーション（1ページ目）
        Case(request: ListTasksRequest(pageSize: 2),
             expectedIDs: ["task-2", "task-1"], totalSize: 5, nextPageToken: "dGFzay0w"), // base64("task-0")
        // ページネーション（同一 timestamp 跨ぎ）
        Case(request: ListTasksRequest(pageSize: 2, pageToken: "dGFzay0x"), // base64("task-1")
             expectedIDs: ["task-1", "task-0"], totalSize: 5, nextPageToken: "dGFzay00"), // base64("task-4")
        // ページネーション（最終ページ）
        Case(request: ListTasksRequest(pageSize: 2, pageToken: "dGFzay0z"), // base64("task-3")
             expectedIDs: ["task-3"], totalSize: 5, nextPageToken: ""),
        // context_id フィルタ
        Case(request: ListTasksRequest(contextId: "context-1"),
             expectedIDs: ["task-1", "task-3"], totalSize: 2, nextPageToken: ""),
        // status フィルタ
        Case(request: ListTasksRequest(status: .working),
             expectedIDs: ["task-1", "task-3"], totalSize: 2, nextPageToken: ""),
        // 複合フィルタ（context_id + status）
        Case(request: ListTasksRequest(contextId: "context-0", status: .submitted),
             expectedIDs: ["task-2", "task-0"], totalSize: 2, nextPageToken: ""),
        // 複合フィルタ + ページネーション
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
        // spec/python: response.pageSize は要求値 or 既定(50)
        let expectedPageSize = (c.request.pageSize ?? 0) > 0 ? c.request.pageSize! : DEFAULT_LIST_TASKS_PAGE_SIZE
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

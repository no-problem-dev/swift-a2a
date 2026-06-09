import Foundation
import Testing
import A2ACore
@testable import A2AServer

/// owner スコープ分離の標準準拠テスト。
///
/// a2a-python `tests/server/tasks/test_inmemory_task_store.py::test_owner_resource_scoping`
/// を 1:1 移植（spec §254/§13.1: クライアントは認可されたタスクのみ参照可）。
@Suite("TaskStore owner scoping (mirror of a2a-python test_owner_resource_scoping)")
struct OwnerScopingTests {

    private func context(_ user: String) -> ServerCallContext {
        ServerCallContext(user: ServerUser(isAuthenticated: true, username: user))
    }

    private func task(_ id: String) -> A2ATask {
        A2ATask(id: TaskID(id), contextId: ContextID("ctx"), status: TaskStatus(state: .submitted))
    }

    @Test("get / list / delete は owner ごとに分離される")
    func ownerScoping() async throws {
        let store = InMemoryTaskStore()
        let user1 = context("user1"), user2 = context("user2"), user3 = context("user3")

        try await store.save(task("u1-task1"), context: user1)
        try await store.save(task("u1-task2"), context: user1)
        try await store.save(task("u2-task1"), context: user2)

        // GET: 自分の owner のものだけ見える
        #expect(try await store.get(TaskID("u1-task1"), context: user1) != nil)
        #expect(try await store.get(TaskID("u1-task1"), context: user2) == nil)
        #expect(try await store.get(TaskID("u2-task1"), context: user1) == nil)
        #expect(try await store.get(TaskID("u2-task1"), context: user2) != nil)
        #expect(try await store.get(TaskID("u2-task1"), context: user3) == nil)

        // LIST: owner ごとの件数
        let p1 = try await store.list(ListTasksRequest(), context: user1)
        #expect(Set(p1.tasks.map(\.id.rawValue)) == ["u1-task1", "u1-task2"])
        #expect(p1.totalSize == 2)
        let p2 = try await store.list(ListTasksRequest(), context: user2)
        #expect(Set(p2.tasks.map(\.id.rawValue)) == ["u2-task1"])
        #expect(p2.totalSize == 1)
        let p3 = try await store.list(ListTasksRequest(), context: user3)
        #expect(p3.tasks.isEmpty)
        #expect(p3.totalSize == 0)

        // DELETE: 他 owner からは削除できない
        try await store.delete(TaskID("u1-task1"), context: user2) // no-op
        #expect(try await store.get(TaskID("u1-task1"), context: user1) != nil)
        try await store.delete(TaskID("u1-task1"), context: user1) // deletes
        #expect(try await store.get(TaskID("u1-task1"), context: user1) == nil)
    }

    @Test("push notification config も owner ごとに分離、配信は owner 横断")
    func pushConfigScopingAndDispatch() async throws {
        let store = InMemoryPushNotificationConfigStore()
        let alice = context("alice"), bob = context("bob")
        let taskId = TaskID("shared-task")

        _ = try await store.set(
            TaskPushNotificationConfig(url: "https://alice.example/hook", taskId: taskId, id: "a"),
            context: alice)
        _ = try await store.set(
            TaskPushNotificationConfig(url: "https://bob.example/hook", taskId: taskId, id: "b"),
            context: bob)

        // 呼び出し系は owner スコープ
        #expect(try await store.get(taskId: taskId, context: alice).map(\.id) == ["a"])
        #expect(try await store.get(taskId: taskId, context: bob).map(\.id) == ["b"])

        // 配信系は owner 横断で全件
        let dispatch = try await store.getForDispatch(taskId: taskId)
        #expect(Set(dispatch.map(\.id)) == ["a", "b"])
    }
}

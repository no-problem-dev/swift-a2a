import Foundation
import Testing
import A2ACore
@testable import A2AServer

/// Conformance for owner scoping: a client sees only the tasks it is authorized for
/// (spec §254, §13.1). Ported case for case from the reference implementation.
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

        // Get: only the caller's own are visible.
        #expect(try await store.get(TaskID("u1-task1"), context: user1) != nil)
        #expect(try await store.get(TaskID("u1-task1"), context: user2) == nil)
        #expect(try await store.get(TaskID("u2-task1"), context: user1) == nil)
        #expect(try await store.get(TaskID("u2-task1"), context: user2) != nil)
        #expect(try await store.get(TaskID("u2-task1"), context: user3) == nil)

        // List: counts are per owner.
        let p1 = try await store.list(ListTasksRequest(), context: user1)
        #expect(Set(p1.tasks.map(\.id.rawValue)) == ["u1-task1", "u1-task2"])
        #expect(p1.totalSize == 2)
        let p2 = try await store.list(ListTasksRequest(), context: user2)
        #expect(Set(p2.tasks.map(\.id.rawValue)) == ["u2-task1"])
        #expect(p2.totalSize == 1)
        let p3 = try await store.list(ListTasksRequest(), context: user3)
        #expect(p3.tasks.isEmpty)
        #expect(p3.totalSize == 0)

        // Delete: one owner cannot remove another's.
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

        // Client-facing lookups stay within one owner.
        #expect(try await store.get(taskId: taskId, context: alice).map(\.id) == ["a"])
        #expect(try await store.get(taskId: taskId, context: bob).map(\.id) == ["b"])

        // Delivery lookup crosses owners and returns everything.
        let dispatch = try await store.configs(forDispatch: taskId)
        #expect(Set(dispatch.map(\.id)) == ["a", "b"])
    }
}

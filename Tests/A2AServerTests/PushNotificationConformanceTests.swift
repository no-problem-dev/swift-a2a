import Foundation
import Testing
import A2ACore
@testable import A2AServer

/// Push 通知の標準準拠テスト。
///
/// a2a-python の config store / BasePushNotificationSender / インライン登録の挙動を移植:
/// - sender は `StreamResponse` JSON を POST し、token があれば `X-A2A-Notification-Token` を付与
/// - SendMessageConfiguration 内 config は on_message_send で store に登録される
/// - config.id 未指定なら taskId を既定 id に採番（同 id は置換）
/// - 配信は owner 横断（getForDispatch）
@Suite("Push notification conformance (mirror of a2a-python)")
struct PushNotificationConformanceTests {

    /// POST を記録する計器。
    actor Recorder {
        struct Hit: Sendable { let url: URL; let body: Data; let headers: [String: String] }
        private(set) var hits: [Hit] = []
        func record(_ hit: Hit) { hits.append(hit) }
    }

    private func recordingSender(_ recorder: Recorder) -> HTTPPushNotificationSender {
        HTTPPushNotificationSender { url, body, headers in
            await recorder.record(.init(url: url, body: body, headers: headers))
        }
    }

    private func card() -> AgentCard {
        AgentCard(
            name: "w", description: "w",
            supportedInterfaces: [AgentInterface(url: "inprocess://local", protocolBinding: "InProcess")],
            version: "1.0.0", capabilities: AgentCapabilities(streaming: true, pushNotifications: true)
        )
    }

    private struct WorkThenComplete: AgentExecutor {
        func execute(_ context: RequestContext, eventQueue: EventQueue) async throws {
            let updater = TaskUpdater(eventQueue: eventQueue, taskId: context.taskId, contextId: context.contextId)
            try await updater.startWork()
            await updater.addArtifact([.text("result")], name: "out")
            try await updater.complete()
        }
        func cancel(_ context: RequestContext, eventQueue: EventQueue) async throws {}
    }

    // MARK: - sender

    @Test("sender は StreamResponse JSON を POST し X-A2A-Notification-Token を付与する")
    func senderPostsStreamResponseWithToken() async throws {
        let recorder = Recorder()
        let sender = recordingSender(recorder)
        let config = TaskPushNotificationConfig(url: "https://hook.example/cb", taskId: TaskID("t"), id: "c", token: "secret")

        let event = StreamResponse.statusUpdate(TaskStatusUpdateEvent(
            taskId: TaskID("t"), contextId: ContextID("c"),
            status: TaskStatus(state: .working)))
        await sender.send(event, to: config)

        let hits = await recorder.hits
        #expect(hits.count == 1)
        let hit = try #require(hits.first)
        #expect(hit.url.absoluteString == "https://hook.example/cb")
        #expect(hit.headers["X-A2A-Notification-Token"] == "secret")
        // payload は StreamResponse（statusUpdate エンベロープ）
        let decoded = try A2AJSON.decoder().decode(StreamResponse.self, from: hit.body)
        guard case .statusUpdate(let u) = decoded else { Issue.record("expected statusUpdate"); return }
        #expect(u.status.state == .working)
    }

    @Test("token 未設定なら X-A2A-Notification-Token は付かない")
    func senderOmitsTokenHeaderWhenAbsent() async throws {
        let recorder = Recorder()
        let sender = recordingSender(recorder)
        let config = TaskPushNotificationConfig(url: "https://hook.example/cb", taskId: TaskID("t"), id: "c")
        await sender.send(.task(A2ATask(id: TaskID("t"), status: TaskStatus(state: .completed))), to: config)
        let hit = try #require(await recorder.hits.first)
        #expect(hit.headers["X-A2A-Notification-Token"] == nil)
    }

    // MARK: - config store id 採番

    @Test("config.id 未指定なら taskId を既定 id に採番し、同一 id 再設定で置換（重複しない）")
    func configIdAutoAssignAndReplace() async throws {
        let store = InMemoryPushNotificationConfigStore()
        let taskId = TaskID("task-x")

        let first = try await store.set(TaskPushNotificationConfig(url: "https://a/cb", taskId: taskId))
        #expect(first.id == "task-x")

        _ = try await store.set(TaskPushNotificationConfig(url: "https://b/cb", taskId: taskId))
        let configs = try await store.get(taskId: taskId)
        #expect(configs.count == 1)            // append でなく置換
        #expect(configs.first?.url == "https://b/cb")
    }

    // MARK: - インライン登録 + end-to-end 配信

    @Test("SendMessageConfiguration 内 config が登録され、タスク進行で webhook へ配信される")
    func inlineConfigRegisteredAndDelivered() async throws {
        let recorder = Recorder()
        let store = InMemoryPushNotificationConfigStore()
        let handler = DefaultRequestHandler(
            agentCard: card(), executor: WorkThenComplete(),
            taskStore: InMemoryTaskStore(), queueManager: InMemoryQueueManager(),
            pushConfigStore: store, pushSender: recordingSender(recorder)
        )
        let taskId = TaskID("push-task")
        let request = SendMessageRequest(
            message: Message(messageId: MessageID("m1"), role: .user, parts: [.text("go")], taskId: taskId),
            configuration: SendMessageConfiguration(
                taskPushNotificationConfig: TaskPushNotificationConfig(url: "https://hook.example/cb", token: "tok"))
        )

        _ = try await handler.onMessageSend(request, context: ServerCallContext())

        // インライン登録: config が store に入っている（taskId 採番済み）
        let stored = try await store.get(taskId: taskId)
        #expect(stored.count == 1)
        #expect(stored.first?.taskId == taskId)

        // 配信: タスク進行（working → artifact → completed）で webhook が叩かれた
        let hits = await recorder.hits
        #expect(!hits.isEmpty)
        // 最終的に completed が配信されている
        let states: [TaskState] = hits.compactMap { hit in
            guard let r = try? A2AJSON.decoder().decode(StreamResponse.self, from: hit.body) else { return nil }
            switch r {
            case .task(let t): return t.status.state
            case .statusUpdate(let u): return u.status.state
            default: return nil
            }
        }
        #expect(states.contains(.completed))
    }
}

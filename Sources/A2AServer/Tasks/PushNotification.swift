import A2ACore
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// プッシュ通知設定の永続化（a2a-python `PushNotificationConfigStore`）。
///
/// 呼び出し系メソッドは owner ごとにスコープ分離する。配信系（`getForDispatch`）は
/// owner 横断で全 config を返す（a2a-python `get_info_for_dispatch`）。
public protocol PushNotificationConfigStore: Sendable {
    func set(_ config: TaskPushNotificationConfig, context: ServerCallContext) async throws -> TaskPushNotificationConfig
    func get(taskId: TaskID, context: ServerCallContext) async throws -> [TaskPushNotificationConfig]
    /// 配信用に owner 横断で全 config を取得（sender が使用）。
    func getForDispatch(taskId: TaskID) async throws -> [TaskPushNotificationConfig]
    func delete(taskId: TaskID, configId: String, context: ServerCallContext) async throws
}

/// context 省略時は未認証コンテキスト（単一スコープ）として扱う利便オーバーロード。
public extension PushNotificationConfigStore {
    func set(_ config: TaskPushNotificationConfig) async throws -> TaskPushNotificationConfig {
        try await set(config, context: ServerCallContext())
    }
    func get(taskId: TaskID) async throws -> [TaskPushNotificationConfig] {
        try await get(taskId: taskId, context: ServerCallContext())
    }
    func delete(taskId: TaskID, configId: String) async throws {
        try await delete(taskId: taskId, configId: configId, context: ServerCallContext())
    }
}

/// タスク更新を webhook へ送信する（a2a-python `PushNotificationSender`）。
public protocol PushNotificationSender: Sendable {
    func send(_ event: StreamResponse, to config: TaskPushNotificationConfig) async
}

/// webhook へ `StreamResponse` JSON を HTTP POST する標準実装（a2a-python `BasePushNotificationSender._dispatch_notification`）。
///
/// payload は `StreamResponse`（task / message / statusUpdate / artifactUpdate のいずれか）。
/// `config.token` があれば `X-A2A-Notification-Token` ヘッダを付与する。
/// テスト容易性のため実 POST は注入可能（既定は URLSession）。
public struct HTTPPushNotificationSender: PushNotificationSender {
    public typealias Post = @Sendable (_ url: URL, _ body: Data, _ headers: [String: String]) async throws -> Void

    private let post: Post

    public init(post: @escaping Post) {
        self.post = post
    }

    public init() {
        self.init(post: Self.urlSessionPost)
    }

    public func send(_ event: StreamResponse, to config: TaskPushNotificationConfig) async {
        guard let url = URL(string: config.url) else { return }
        guard let body = try? A2AJSON.encoder().encode(event) else { return }
        var headers = ["Content-Type": A2AProtocol.jsonContentType]
        if let token = config.token { headers["X-A2A-Notification-Token"] = token }
        try? await post(url, body, headers)
    }

    static let urlSessionPost: Post = { url, body, headers in
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        _ = try await URLSession.shared.data(for: request)
    }
}

public actor InMemoryPushNotificationConfigStore: PushNotificationConfigStore {
    /// owner -> taskId -> [config]（a2a-python InMemoryPushNotificationConfigStore）。
    private var configsByOwner: [String: [TaskID: [TaskPushNotificationConfig]]] = [:]
    private let ownerResolver: OwnerResolver

    public init() {
        self.ownerResolver = resolveUserScope
    }

    public init(ownerResolver: @escaping OwnerResolver) {
        self.ownerResolver = ownerResolver
    }

    public func set(_ config: TaskPushNotificationConfig, context: ServerCallContext) async throws -> TaskPushNotificationConfig {
        guard let taskId = config.taskId else {
            throw A2AServerError.invalidParams("TaskPushNotificationConfig.taskId is required")
        }
        // a2a-python: id 未指定なら taskId を既定 id に採番（同一 id は置換）。
        var stored = config
        if stored.id == nil { stored.id = taskId.rawValue }
        let owner = ownerResolver(context)
        var list = configsByOwner[owner]?[taskId] ?? []
        if let index = list.firstIndex(where: { $0.id == stored.id }) {
            list[index] = stored
        } else {
            list.append(stored)
        }
        configsByOwner[owner, default: [:]][taskId] = list
        return stored
    }

    public func get(taskId: TaskID, context: ServerCallContext) async throws -> [TaskPushNotificationConfig] {
        configsByOwner[ownerResolver(context)]?[taskId] ?? []
    }

    public func getForDispatch(taskId: TaskID) async throws -> [TaskPushNotificationConfig] {
        configsByOwner.values.compactMap { $0[taskId] }.flatMap { $0 }
    }

    public func delete(taskId: TaskID, configId: String, context: ServerCallContext) async throws {
        configsByOwner[ownerResolver(context)]?[taskId]?.removeAll { $0.id == configId }
    }
}

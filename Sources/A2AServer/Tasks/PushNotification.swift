import A2ACore
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Where webhook registrations live.
///
/// Two access patterns, deliberately different. The context-taking methods serve client requests
/// and are scoped by owner, so one caller cannot see another's webhooks. Delivery uses
/// `configs(forDispatch:)`, which crosses owners on purpose: an event belongs to a task, and every
/// registration on that task must receive it regardless of who made it.
public protocol PushNotificationConfigStore: Sendable {
    /// Stores a configuration, replacing any already held under the same `id` for that task.
    func set(_ config: TaskPushNotificationConfig, context: ServerCallContext) async throws -> TaskPushNotificationConfig
    /// Returns the configurations the caller registered on a task.
    func get(taskId: TaskID, context: ServerCallContext) async throws -> [TaskPushNotificationConfig]
    /// Returns every configuration on a task, from every owner. For delivery only — never answer a
    /// client request with this.
    func configs(forDispatch taskId: TaskID) async throws -> [TaskPushNotificationConfig]
    /// Removes one of the caller's configurations. Removing one that does not exist is not an error.
    func delete(taskId: TaskID, configId: String, context: ServerCallContext) async throws
}

/// Overloads that drop the context, standing in for an unauthenticated caller — that is, the one
/// shared scope. Convenient in tests; wrong in a deployment that serves more than one client.
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

/// Delivers a task event to one registered destination.
///
/// Deliberately cannot fail: `send` neither throws nor reports a result, so delivery problems are
/// the sender's to handle. Retry and dead-lettering belong inside an implementation, not around it.
public protocol PushNotificationSender: Sendable {
    /// Delivers one event. Called once per registered configuration, in no guaranteed order.
    func send(_ event: StreamResponse, to config: TaskPushNotificationConfig) async
}

/// POSTs each event as JSON to the registered URL.
///
/// The body is the event itself, in the same shape a stream would deliver. A configuration's token
/// travels in the `X-A2A-Notification-Token` header so the receiver can confirm the delivery is
/// one it asked for; the configuration's `authentication` is *not* applied.
///
/// Everything fails silently: an unparseable URL, an encoding failure, a non-2xx response and a
/// connection error all end in the event being dropped with nothing recorded. Supply your own
/// `post` to get logging or retries.
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
        guard let body = try? A2AJSON.makeEncoder().encode(event) else { return }
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

/// Hands each event to a closure instead of sending it anywhere.
///
/// The registration and triggering machinery is unchanged — only the delivery step differs — so an
/// in-process agent can notify its host through the same path a remote one would use over HTTP.
/// The configuration's URL is passed through untouched and may be a placeholder.
public struct InProcessPushNotificationSender: PushNotificationSender {
    public typealias Sink = @Sendable (_ event: StreamResponse, _ config: TaskPushNotificationConfig) async -> Void

    private let sink: Sink

    public init(sink: @escaping Sink) {
        self.sink = sink
    }

    public func send(_ event: StreamResponse, to config: TaskPushNotificationConfig) async {
        await sink(event, config)
    }
}

/// Holds webhook configurations in a dictionary, partitioned by owner. For prototyping and tests —
/// nothing survives a restart.
///
/// A configuration with no `id` is stored under the task ID, so registering twice without an
/// explicit id replaces rather than accumulates.
public actor InMemoryPushNotificationConfigStore: PushNotificationConfigStore {
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
        // Default the id to the task id, so an unnamed registration is replaced rather than
        // duplicated on the next call.
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

    public func configs(forDispatch taskId: TaskID) async throws -> [TaskPushNotificationConfig] {
        configsByOwner.values.compactMap { $0[taskId] }.flatMap { $0 }
    }

    public func delete(taskId: TaskID, configId: String, context: ServerCallContext) async throws {
        configsByOwner[ownerResolver(context)]?[taskId]?.removeAll { $0.id == configId }
    }
}

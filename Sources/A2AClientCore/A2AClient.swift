import Foundation
import A2ACore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The client you call. Every method delegates to a transport, so the same code works over REST,
/// JSON-RPC or a direct in-process handler.
///
/// Build one with the factory the binding module adds — `A2AClient.rest(baseURL:)`,
/// `A2AClient.jsonRPC(endpoint:)` or `A2AClient.inProcess(handler:)` — rather than by hand.
///
/// A value type with no mutable state: it is safe to share, and it holds no connection of its own.
public struct A2AClient: Sendable {
    public let configuration: A2AClientConfiguration
    public let transport: any A2ATransport
    private let http: HTTPClient

    public init(transport: any A2ATransport, http: HTTPClient, configuration: A2AClientConfiguration) {
        self.transport = transport
        self.http = http
        self.configuration = configuration
    }

    // MARK: - Messaging

    /// Sends a message and waits for the agent to finish or stop for input.
    ///
    /// Returns a task when the agent tracked the work, or a message when it simply replied. Pass
    /// `returnImmediately` in the configuration to get the task back as soon as it exists instead.
    public func sendMessage(
        _ message: Message,
        configuration: SendMessageConfiguration? = nil,
        metadata: A2AMetadata? = nil
    ) async throws -> SendMessageResponse {
        try await transport.sendMessage(
            SendMessageRequest(message: message, configuration: configuration, metadata: metadata)
        )
    }

    /// Sends a fully built request, for the fields the convenience overload does not expose.
    public func sendMessage(_ request: SendMessageRequest) async throws -> SendMessageResponse {
        try await transport.sendMessage(request)
    }

    /// Sends a message and returns the updates as they happen.
    ///
    /// The stream ends when the task reaches a terminal or interrupted state, or when the agent
    /// replies with a message. Requires the agent to advertise the streaming capability.
    public func streamMessage(
        _ message: Message,
        configuration: SendMessageConfiguration? = nil,
        metadata: A2AMetadata? = nil
    ) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        try await transport.sendStreamingMessage(
            SendMessageRequest(message: message, configuration: configuration, metadata: metadata)
        )
    }

    // MARK: - Tasks

    /// Fetches a task as it stands.
    ///
    /// - Parameters:
    ///   - id: The task to fetch.
    ///   - historyLength: How many of the most recent messages to include. All of them by default.
    public func getTask(_ id: TaskID, historyLength: Int? = nil) async throws -> A2ATask {
        try await transport.getTask(GetTaskRequest(id: id, historyLength: historyLength))
    }

    /// Fetches a page of tasks, newest first by status timestamp.
    public func listTasks(_ request: ListTasksRequest = ListTasksRequest()) async throws -> ListTasksResponse {
        try await transport.listTasks(request)
    }

    /// Asks the agent to stop a task, returning it in its final state.
    ///
    /// - Throws: `A2AError.rpc` with `taskNotCancelable` if the task has already finished, or if
    ///   the agent declines to cancel it.
    public func cancelTask(_ id: TaskID, metadata: A2AMetadata? = nil) async throws -> A2ATask {
        try await transport.cancelTask(CancelTaskRequest(id: id, metadata: metadata))
    }

    /// Follows a task that is already running.
    ///
    /// The first event is always a snapshot of the task as it stands, so nothing is missed between
    /// the fetch and the subscription.
    ///
    /// - Throws: `A2AError.rpc` if the task is unknown or has already finished.
    public func subscribeToTask(_ id: TaskID) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        try await transport.subscribeToTask(SubscribeToTaskRequest(id: id))
    }

    // MARK: - Push notification configs

    /// Registers a webhook to receive a task's updates.
    ///
    /// Re-registering with an existing `id` replaces that configuration rather than adding another.
    public func createPushNotificationConfig(_ config: TaskPushNotificationConfig) async throws -> TaskPushNotificationConfig {
        try await transport.createTaskPushNotificationConfig(config)
    }

    /// Fetches one webhook configuration.
    public func getPushNotificationConfig(taskId: TaskID, id: String) async throws -> TaskPushNotificationConfig {
        try await transport.getTaskPushNotificationConfig(
            GetTaskPushNotificationConfigRequest(taskId: taskId, id: id)
        )
    }

    /// Lists the webhook configurations registered on a task.
    public func listPushNotificationConfigs(taskId: TaskID) async throws -> ListTaskPushNotificationConfigsResponse {
        try await transport.listTaskPushNotificationConfigs(
            ListTaskPushNotificationConfigsRequest(taskId: taskId)
        )
    }

    /// Removes a webhook configuration.
    public func deletePushNotificationConfig(taskId: TaskID, id: String) async throws {
        try await transport.deleteTaskPushNotificationConfig(
            DeleteTaskPushNotificationConfigRequest(taskId: taskId, id: id)
        )
    }

    // MARK: - Agent Card

    /// Fetches the agent's public card from the host's well-known path.
    ///
    /// A plain GET that bypasses the transport, so it works the same whichever binding the client
    /// was built with. The base URL's path, query and fragment are discarded — the card is looked
    /// up at the host root, not relative to the endpoint.
    ///
    /// - Throws: `A2AError.http` on a non-2xx response, `A2AError.decoding` if the body is not a
    ///   card, `A2AError.invalidResponse` if the base URL cannot be rewritten.
    public func fetchAgentCard() async throws -> AgentCard {
        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
            throw A2AError.invalidResponse("Invalid base URL")
        }
        components.path = A2AProtocol.agentCardWellKnownPath
        components.query = nil
        components.fragment = nil
        guard let url = components.url else {
            throw A2AError.invalidResponse("Cannot build well-known Agent Card URL")
        }

        let request = http.makeRequest(url: url, method: "GET", accept: A2AProtocol.jsonContentType)
        let (data, response) = try await http.send(request)
        guard (200...299).contains(response.statusCode) else {
            throw A2AError.http(status: response.statusCode, body: String(data: data, encoding: .utf8))
        }
        do {
            return try A2AJSON.makeDecoder().decode(AgentCard.self, from: data)
        } catch {
            throw A2AError.decoding(error)
        }
    }

    /// Fetches the fuller card available to authenticated callers.
    ///
    /// Unlike `fetchAgentCard()` this goes through the transport, so it carries the credential.
    ///
    /// - Throws: `A2AError.rpc` with `extendedAgentCardNotConfigured` if the agent does not offer
    ///   one.
    public func fetchExtendedAgentCard() async throws -> AgentCard {
        try await transport.getExtendedAgentCard(GetExtendedAgentCardRequest())
    }
}

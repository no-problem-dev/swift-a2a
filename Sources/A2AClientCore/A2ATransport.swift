import A2ACore

/// The eleven A2A operations, stated once so a binding can be swapped without touching call sites.
///
/// The specification requires the bindings to be functionally equivalent (§5.1), which is what
/// makes one protocol possible: each conformer owns its own wire mapping, envelope shape and error
/// representation, and none of that surfaces here. Failures arrive as `A2AError` regardless of
/// which binding produced them.
///
/// Implemented here by the REST, JSON-RPC and in-process bindings. gRPC is not implemented.
public protocol A2ATransport: Sendable {
    /// Sends a message and waits for the outcome.
    func sendMessage(_ request: SendMessageRequest) async throws -> SendMessageResponse

    /// Sends a message and returns a stream of updates, ending on a terminal or interrupted state.
    func sendStreamingMessage(_ request: SendMessageRequest) async throws -> AsyncThrowingStream<StreamResponse, Error>

    /// Fetches a task as it stands.
    func getTask(_ request: GetTaskRequest) async throws -> A2ATask

    /// Fetches a page of tasks, newest first.
    func listTasks(_ request: ListTasksRequest) async throws -> ListTasksResponse

    /// Asks the agent to stop a task, returning it in its final state.
    func cancelTask(_ request: CancelTaskRequest) async throws -> A2ATask

    /// Follows a task that is already running. The first event is always a snapshot of the task.
    func subscribeToTask(_ request: SubscribeToTaskRequest) async throws -> AsyncThrowingStream<StreamResponse, Error>

    /// Registers a webhook for a task's updates.
    func createTaskPushNotificationConfig(_ config: TaskPushNotificationConfig) async throws -> TaskPushNotificationConfig

    /// Fetches one webhook configuration.
    func getTaskPushNotificationConfig(_ request: GetTaskPushNotificationConfigRequest) async throws -> TaskPushNotificationConfig

    /// Lists the webhook configurations on a task.
    func listTaskPushNotificationConfigs(_ request: ListTaskPushNotificationConfigsRequest) async throws -> ListTaskPushNotificationConfigsResponse

    /// Removes a webhook configuration.
    func deleteTaskPushNotificationConfig(_ request: DeleteTaskPushNotificationConfigRequest) async throws

    /// Fetches the fuller card available to authenticated callers.
    func getExtendedAgentCard(_ request: GetExtendedAgentCardRequest) async throws -> AgentCard
}

import A2ACore

/// The agent itself: the one type you write to serve A2A.
///
/// Everything around it — task persistence, event fan-out, push delivery, transport encoding — is
/// the framework's job. An executor reads the request and publishes events.
///
/// ``TaskUpdater`` is the convenient way to publish: it stamps timestamps and enforces that
/// nothing follows a terminal state.
public protocol AgentExecutor: Sendable {
    /// Does the work, publishing events until the task reaches a terminal or interrupted state.
    ///
    /// Return only after publishing that final state; returning early leaves the caller waiting on
    /// a task that never resolves. Publishing `.inputRequired` ends this run, and the framework
    /// calls `execute` again with the same task when the client's reply arrives — so an executor
    /// must be able to resume from `context.currentTask` rather than assuming a fresh start.
    ///
    /// Throwing is a legitimate way to fail: the framework publishes a failed status on your
    /// behalf. Cancellation is not an error — a cancelled run is treated as a normal end.
    ///
    /// - Parameters:
    ///   - context: The request, the resolved identifiers, and the caller.
    ///   - eventQueue: Where to publish status updates and artifacts. The framework closes it.
    func execute(_ context: RequestContext, eventQueue: EventQueue) async throws

    /// Stops a running task and publishes a canceled status.
    ///
    /// Called on a separate queue from the run being stopped, which has already been cancelled by
    /// the time this is invoked. The task is only reported as cancelled if this leaves it in the
    /// canceled state; an executor that declines makes the request fail as not cancelable.
    func cancel(_ context: RequestContext, eventQueue: EventQueue) async throws
}

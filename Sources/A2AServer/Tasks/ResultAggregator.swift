import A2ACore

/// Consumes an event stream through a ``TaskManager`` and reports the outcome.
///
/// - Note: ``DefaultRequestHandler`` does not use this type; it drives its stream itself. This is
///   here for custom handlers that want the same consumption rules without reimplementing them.
public actor ResultAggregator {
    private let taskManager: TaskManager

    public init(taskManager: TaskManager) {
        self.taskManager = taskManager
    }

    /// The task folded so far, or `nil` if no event has created one.
    public func currentResult() async -> SendMessageResponse? {
        if let task = await taskManager.getTask() {
            return .task(task)
        }
        return nil
    }

    /// Consumes events until the outcome is settled.
    ///
    /// Stops at the first of: a direct message, an interrupted state, a terminal state, or — when
    /// not blocking — the moment a task exists at all. A stream that ends without any of those
    /// yields whatever was folded.
    ///
    /// - Parameters:
    ///   - stream: The events to consume. Not drained past the stopping point, so the rest keeps
    ///     buffering unless someone else reads it.
    ///   - blocking: Whether to wait for the task to settle rather than returning as soon as it
    ///     exists.
    /// - Returns: The outcome, and whether it stopped early — on an interrupt or because it was
    ///   not blocking — rather than on a settled result.
    public func consumeAndBreakOnInterrupt(
        _ stream: AsyncStream<StreamResponse>,
        blocking: Bool
    ) async throws -> (result: SendMessageResponse?, interruptedOrNonBlocking: Bool) {
        for await event in stream {
            try await taskManager.process(event)

            if case .message(let message) = event {
                return (.message(message), false)
            }
            if event.isInterrupt {
                return (await currentResult(), true)
            }
            if event.isFinal {
                return (await currentResult(), false)
            }
            if !blocking, await taskManager.getTask() != nil {
                return (await currentResult(), true)
            }
        }
        return (await currentResult(), false)
    }

    /// Consumes every event to the end of the stream, persisting each. For a run whose result
    /// nobody is waiting on.
    public func consumeAll(_ stream: AsyncStream<StreamResponse>) async throws {
        for await event in stream {
            try await taskManager.process(event)
        }
    }
}

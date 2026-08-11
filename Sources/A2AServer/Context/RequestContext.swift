import A2ACore

/// Everything an executor is given about the request it is handling.
///
/// The identifiers are already resolved: the handler reuses the ones the message named and mints
/// UUIDs for whichever are missing, so an executor never has to decide whether a task is new.
public struct RequestContext: Sendable {
    /// The message that triggered this run. `nil` when the run is a cancellation.
    public let message: Message?
    /// The task being worked on, whether it was just created or is being continued.
    public let taskId: TaskID
    /// The conversation the task belongs to.
    public let contextId: ContextID
    /// The task as stored before this run, or `nil` if it is new. A non-`nil` value means the
    /// executor is resuming work that stopped for input.
    public let currentTask: A2ATask?
    /// Tasks the message referenced as context. Not populated by the handler shipped here.
    public let relatedTasks: [A2ATask]
    /// Who is calling and which extensions they asked for.
    public let callContext: ServerCallContext

    public init(
        message: Message?,
        taskId: TaskID,
        contextId: ContextID,
        currentTask: A2ATask? = nil,
        relatedTasks: [A2ATask] = [],
        callContext: ServerCallContext = ServerCallContext()
    ) {
        self.message = message
        self.taskId = taskId
        self.contextId = contextId
        self.currentTask = currentTask
        self.relatedTasks = relatedTasks
        self.callContext = callContext
    }

    /// The text of the triggering message, with non-text parts skipped.
    ///
    /// - Parameter delimiter: What to place between parts. A newline by default.
    /// - Returns: The joined text, or an empty string when there is no message — as on a
    ///   cancellation run.
    public func userInput(delimiter: String = "\n") -> String {
        guard let message else { return "" }
        return message.parts.compactMap(\.text).joined(separator: delimiter)
    }
}

import A2ACore

/// 1 リクエストの処理コンテキスト（a2a-python `RequestContext`）。
/// `taskId` / `contextId` は `DefaultRequestHandler` が解決・採番して構築する。
public struct RequestContext: Sendable {
    public let message: Message?
    public let taskId: TaskID
    public let contextId: ContextID
    public let currentTask: A2ATask?
    public let relatedTasks: [A2ATask]
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

    public func getUserInput(delimiter: String = "\n") -> String {
        guard let message else { return "" }
        return message.parts.compactMap(\.text).joined(separator: delimiter)
    }
}

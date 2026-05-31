import A2ACore

/// 1 リクエストの処理コンテキスト（a2a-python `RequestContext`）。
///
/// 受信メッセージ・タスク/コンテキスト識別子・既存タスク・関連タスクを保持します。
/// `taskId` / `contextId` は `DefaultRequestHandler` が解決・採番した上で構築します。
public struct RequestContext: Sendable {
    /// 受信した `Message`（`message/send` 以外では `nil`）。
    public let message: Message?
    /// 解決済みのタスク ID。
    public let taskId: TaskID
    /// 解決済みのコンテキスト ID。
    public let contextId: ContextID
    /// ストアから取得した既存タスク（あれば）。
    public let currentTask: A2ATask?
    /// 本リクエストに関連するタスク（ツール実行などで生成されたもの）。
    public let relatedTasks: [A2ATask]
    /// サーバ呼び出しコンテキスト。
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

    /// ユーザーメッセージのテキストパートを連結して返す。
    public func getUserInput(delimiter: String = "\n") -> String {
        guard let message else { return "" }
        return message.parts.compactMap(\.text).joined(separator: delimiter)
    }
}

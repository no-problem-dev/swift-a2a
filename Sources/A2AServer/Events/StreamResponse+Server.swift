import A2ACore

/// サーバ内部で `StreamResponse`（A2A 仕様の streaming/push ペイロード型）を
/// 判定・分類するためのヘルパ。新しい型は導入せず、仕様型に対する内部アクセサのみ。
extension StreamResponse {
    /// イベントが参照するタスク ID（メッセージにタスク ID が無ければ `nil`）。
    var taskID: TaskID? {
        switch self {
        case .task(let task): task.id
        case .statusUpdate(let event): event.taskId
        case .artifactUpdate(let event): event.taskId
        case .message(let message): message.taskId
        }
    }

    /// イベントが参照するコンテキスト ID。
    var contextID: ContextID? {
        switch self {
        case .task(let task): task.contextId
        case .statusUpdate(let event): event.contextId
        case .artifactUpdate(let event): event.contextId
        case .message(let message): message.contextId
        }
    }

    /// 終端イベント（Message 応答、または終端状態の Task/TaskStatusUpdateEvent）かどうか。
    var isFinal: Bool {
        switch self {
        case .message: true
        case .statusUpdate(let event): event.status.state.isTerminal
        case .task(let task): task.status.state.isTerminal
        case .artifactUpdate: false
        }
    }

    /// 中断イベント（input-required / auth-required）かどうか。
    var isInterrupt: Bool {
        switch self {
        case .statusUpdate(let event): event.status.state.isInterrupted
        case .task(let task): task.status.state.isInterrupted
        case .message, .artifactUpdate: false
        }
    }
}

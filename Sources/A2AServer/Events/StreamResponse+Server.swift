import A2ACore

// サーバ内部で仕様型 `StreamResponse` を判定・分類するアクセサ（新しい型は導入しない）。
extension StreamResponse {
    var taskID: TaskID? {
        switch self {
        case .task(let task): task.id
        case .statusUpdate(let event): event.taskId
        case .artifactUpdate(let event): event.taskId
        case .message(let message): message.taskId
        }
    }

    var contextID: ContextID? {
        switch self {
        case .task(let task): task.contextId
        case .statusUpdate(let event): event.contextId
        case .artifactUpdate(let event): event.contextId
        case .message(let message): message.contextId
        }
    }

    var isFinal: Bool {
        switch self {
        case .message: true
        case .statusUpdate(let event): event.status.state.isTerminal
        case .task(let task): task.status.state.isTerminal
        case .artifactUpdate: false
        }
    }

    var isInterrupt: Bool {
        switch self {
        case .statusUpdate(let event): event.status.state.isInterrupted
        case .task(let task): task.status.state.isInterrupted
        case .message, .artifactUpdate: false
        }
    }
}

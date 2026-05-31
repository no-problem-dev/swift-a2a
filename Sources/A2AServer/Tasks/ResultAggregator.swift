import A2ACore

/// `EventQueue` から消費したイベントを `TaskManager` で集約し、最終結果
/// （`Task` または `Message`）を得る（a2a-python `ResultAggregator`）。
public actor ResultAggregator {
    private let taskManager: TaskManager

    public init(taskManager: TaskManager) {
        self.taskManager = taskManager
    }

    /// 現在のタスク状態。
    public func currentResult() async -> SendMessageResponse? {
        if let task = await taskManager.getTask() {
            return .task(task)
        }
        return nil
    }

    /// イベントを消費し、終端／中断で打ち切って結果を返す。
    ///
    /// - Parameters:
    ///   - stream: 消費対象のイベントストリーム（`EventQueue.tap()`）。
    ///   - blocking: `true` なら終端/中断まで待つ。`false`（`returnImmediately`）なら
    ///     最初のタスク/メッセージ確定時点で打ち切る。
    /// - Returns: 確定結果と、中断（input/auth required）または非ブロッキング打ち切りで
    ///   抜けたかどうか。
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
                // returnImmediately: タスクが確定したら即返し、消費は呼び出し側が継続。
                return (await currentResult(), true)
            }
        }
        return (await currentResult(), false)
    }

    /// 終端まで全イベントを消費して `TaskManager` に反映する（streaming 応答用）。
    public func consumeAll(_ stream: AsyncStream<StreamResponse>) async throws {
        for await event in stream {
            try await taskManager.process(event)
        }
    }
}

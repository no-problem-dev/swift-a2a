import A2ACore

/// `EventQueue` のイベントを `TaskManager` で集約し最終結果を得る（a2a-python `ResultAggregator`）。
public actor ResultAggregator {
    private let taskManager: TaskManager

    public init(taskManager: TaskManager) {
        self.taskManager = taskManager
    }

    public func currentResult() async -> SendMessageResponse? {
        if let task = await taskManager.getTask() {
            return .task(task)
        }
        return nil
    }

    /// 終端／中断まで（`blocking: false` なら最初の確定まで）消費して結果を返す。
    /// 戻り値の Bool は中断/非ブロッキング打ち切りで抜けたか。
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

    public func consumeAll(_ stream: AsyncStream<StreamResponse>) async throws {
        for await event in stream {
            try await taskManager.process(event)
        }
    }
}

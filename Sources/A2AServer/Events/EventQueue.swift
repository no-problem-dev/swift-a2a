import A2ACore
import Foundation

/// `AgentExecutor` が `StreamResponse` を publish する producer 側キュー（a2a-python `EventQueue`）。
/// `DefaultRequestHandler` が生成して `execute`/`cancel` に渡す。`tap()` 以降のイベントのみが届く。
public actor EventQueue {
    private var taps: [UUID: AsyncStream<StreamResponse>.Continuation] = [:]
    private var closed = false

    public init() {}

    public func enqueue(_ event: StreamResponse) {
        guard !closed else { return }
        for continuation in taps.values {
            continuation.yield(event)
        }
    }

    public func tap() -> AsyncStream<StreamResponse> {
        if closed {
            return AsyncStream { $0.finish() }
        }
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: StreamResponse.self, bufferingPolicy: .unbounded)
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeTap(id) }
        }
        taps[id] = continuation
        return stream
    }

    public func close() {
        guard !closed else { return }
        closed = true
        for continuation in taps.values {
            continuation.finish()
        }
        taps.removeAll()
    }

    public var isClosed: Bool { closed }

    private func removeTap(_ id: UUID) {
        taps[id] = nil
    }
}

import A2ACore
import Foundation

/// Where an executor publishes its events, and where the framework and any subscribers read them.
///
/// A broadcast queue with no history: `tap()` returns a stream of events enqueued *after* the tap,
/// so a subscriber that arrives late has missed what came before. That is why a subscription is
/// opened with a task snapshot rather than a replay.
///
/// Each tap buffers without bound, so a consumer that stops reading holds every subsequent event
/// in memory until it drops the stream.
public actor EventQueue {
    private var taps: [UUID: AsyncStream<StreamResponse>.Continuation] = [:]
    private var closed = false

    public init() {}

    /// Publishes an event to every current tap.
    ///
    /// Does nothing once the queue is closed — an executor that publishes after closing loses the
    /// event with no error.
    public func enqueue(_ event: StreamResponse) {
        guard !closed else { return }
        for continuation in taps.values {
            continuation.yield(event)
        }
    }

    /// Opens a stream of the events published from now on.
    ///
    /// Taps are independent: each sees every subsequent event. A tap taken after `close()` is
    /// already finished and yields nothing. Dropping the stream removes the tap.
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

    /// Finishes every tap and refuses further events. Idempotent, and not reversible.
    public func close() {
        guard !closed else { return }
        closed = true
        for continuation in taps.values {
            continuation.finish()
        }
        taps.removeAll()
    }

    /// Whether the queue has been closed.
    public var isClosed: Bool { closed }

    private func removeTap(_ id: UUID) {
        taps[id] = nil
    }
}

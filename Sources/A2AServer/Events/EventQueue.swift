import A2ACore
import Foundation

/// `AgentExecutor` が実行結果を publish する producer 側のキュー。
///
/// proto に定義された型ではなく、リファレンス実装（a2a-python `EventQueue`）の
/// サーバ構造を写経したもの。運ぶペイロードは A2A 仕様の `StreamResponse`
/// （oneof: task / message / status_update / artifact_update）そのもの。
///
/// `DefaultRequestHandler` が生成し `execute`/`cancel` に渡します。executor は
/// `enqueue(_:)` でイベントを流すだけで、消費側は framework が管理します。
/// `tap()` 以降に enqueue されたイベントのみがそのストリームに届きます。
public actor EventQueue {
    private var taps: [UUID: AsyncStream<StreamResponse>.Continuation] = [:]
    private var closed = false

    public init() {}

    /// イベントを全消費ストリームへ流す。終了後は無視される。
    public func enqueue(_ event: StreamResponse) {
        guard !closed else { return }
        for continuation in taps.values {
            continuation.yield(event)
        }
    }

    /// このキューを購読する消費ストリームを派生する。
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

    /// キューを閉じる。全消費ストリームが終端する。
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

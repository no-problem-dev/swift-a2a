import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Turns a byte stream into Server-Sent Events.
///
/// Lines are assembled from raw bytes rather than taken from `AsyncLineSequence`, which can drop
/// the blank line that separates events — and in SSE the blank line *is* the event boundary.
///
/// Only events carrying at least one `data` line are emitted: comments and bare heartbeats are
/// consumed and discarded. Unknown field names are ignored, as the format requires.
public struct SSEParser: Sendable {
    /// One dispatched event.
    public struct Event: Sendable {
        public let event: String?
        public let data: String
        public let id: String?
        public let retry: Int?
    }

    /// Parses events from a byte stream, in order.
    ///
    /// A trailing event with no closing blank line is still emitted when the stream ends. The
    /// `id` and `retry` fields are parsed and handed over, but nothing here acts on them — this
    /// parser never reconnects.
    ///
    /// Cancelling iteration cancels the underlying read.
    public static func events(
        from bytes: URLSession.AsyncBytes
    ) -> AsyncThrowingStream<Event, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var event: String?
                var dataLines: [String] = []
                var id: String?
                var retry: Int?
                var lineBytes: [UInt8] = []

                func dispatch() {
                    guard !dataLines.isEmpty else { return }
                    continuation.yield(
                        Event(event: event, data: dataLines.joined(separator: "\n"), id: id, retry: retry)
                    )
                    event = nil
                    dataLines = []
                    id = nil
                    retry = nil
                }

                func handle(line rawLine: String) {
                    var line = rawLine
                    if line.hasSuffix("\r") { line.removeLast() }
                    if line.isEmpty { dispatch(); return }
                    if line.hasPrefix(":") { return } // Comment line.

                    let (field, value) = Self.parseField(line)
                    switch field {
                    case "event": event = value
                    case "data": dataLines.append(value)
                    case "id": id = value
                    case "retry": retry = Int(value)
                    default: break
                    }
                }

                do {
                    for try await byte in bytes {
                        if byte == 0x0A { // \n
                            handle(line: String(decoding: lineBytes, as: UTF8.self))
                            lineBytes.removeAll(keepingCapacity: true)
                        } else {
                            lineBytes.append(byte)
                        }
                    }
                    if !lineBytes.isEmpty {
                        handle(line: String(decoding: lineBytes, as: UTF8.self))
                    }
                    dispatch()
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func parseField(_ line: String) -> (field: String, value: String) {
        guard let colon = line.firstIndex(of: ":") else { return (line, "") }
        let field = String(line[line.startIndex..<colon])
        var value = String(line[line.index(after: colon)...])
        if value.hasPrefix(" ") { value.removeFirst() }
        return (field, value)
    }
}

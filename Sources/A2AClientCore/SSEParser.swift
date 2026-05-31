import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Server-Sent Events パーサー。`URLSession.AsyncBytes` を直接消費し、イベント境界（空行）を確実に検出します。
///
/// `AsyncLineSequence` は空行を取りこぼすことがあるため、バイト列から行を組み立てて解析します。
public struct SSEParser: Sendable {
    /// 1 件の SSE イベント。
    public struct Event: Sendable {
        public let event: String?
        public let data: String
        public let id: String?
        public let retry: Int?
    }

    /// バイトストリームから SSE イベントを非同期に解析します。
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
                    if line.hasPrefix(":") { return } // コメント

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

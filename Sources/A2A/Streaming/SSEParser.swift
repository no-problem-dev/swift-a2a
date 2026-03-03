import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - SSEParser

/// Server-Sent Events パーサー
///
/// URLSession.bytes ベースの SSE ストリームをパースし、
/// イベントを非同期シーケンスとして提供します。
internal struct SSEParser {
    /// SSEイベント
    struct Event: Sendable {
        let type: String?
        let data: String
        let id: String?
        let retry: Int?
    }

    /// URLSessionのbytesストリームからSSEイベントを非同期的にパース
    ///
    /// - Parameter lines: URLSession.AsyncBytesの行イテレータ
    /// - Returns: SSEイベントの非同期ストリーム
    static func parse(lines: AsyncLineSequence<URLSession.AsyncBytes>) -> AsyncThrowingStream<Event, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var eventType: String? = nil
                var dataLines: [String] = []
                var eventId: String? = nil
                var retry: Int? = nil

                do {
                    for try await line in lines {
                        // 空行 = イベントの区切り
                        if line.isEmpty {
                            if !dataLines.isEmpty {
                                let event = Event(
                                    type: eventType,
                                    data: dataLines.joined(separator: "\n"),
                                    id: eventId,
                                    retry: retry
                                )
                                continuation.yield(event)
                            }
                            // リセット
                            eventType = nil
                            dataLines = []
                            eventId = nil
                            retry = nil
                            continue
                        }

                        // コメント行
                        if line.hasPrefix(":") {
                            continue
                        }

                        // フィールド解析
                        let (field, value) = parseField(line)
                        switch field {
                        case "event":
                            eventType = value
                        case "data":
                            dataLines.append(value)
                        case "id":
                            eventId = value
                        case "retry":
                            retry = Int(value)
                        default:
                            break
                        }
                    }

                    // 残りのデータがあれば最後のイベントとして発行
                    if !dataLines.isEmpty {
                        let event = Event(
                            type: eventType,
                            data: dataLines.joined(separator: "\n"),
                            id: eventId,
                            retry: retry
                        )
                        continuation.yield(event)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// SSEフィールド行をパース
    private static func parseField(_ line: String) -> (field: String, value: String) {
        if let colonIndex = line.firstIndex(of: ":") {
            let field = String(line[line.startIndex..<colonIndex])
            var value = String(line[line.index(after: colonIndex)...])
            // 値の先頭スペースを除去（SSE仕様）
            if value.hasPrefix(" ") {
                value = String(value.dropFirst())
            }
            return (field, value)
        }
        return (line, "")
    }
}

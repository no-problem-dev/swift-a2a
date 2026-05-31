import Foundation
import StructuredDataCore

/// A2A クライアントのエラー。
public enum A2AError: Error, Sendable {
    /// バインディングが報告した A2A／JSON-RPC エラー。
    case rpc(A2ARemoteError)
    /// 2xx 以外の HTTP 応答（構造化エラーとして解釈できなかった場合）。
    case http(status: Int, body: String?)
    /// 結果が空だった。
    case emptyResult
    /// 応答が不正・想定外。
    case invalidResponse(String)
    /// レスポンスの復号失敗。
    case decoding(any Error)
    /// リクエストの符号化失敗。
    case encoding(any Error)
    /// タイムアウト。
    case timeout
    /// トランスポート（接続）エラー。
    case transport(any Error)
}

/// リモートが返した構造化エラー（JSON-RPC error / google.rpc.Status を統一表現）。
public struct A2ARemoteError: Error, Sendable, Hashable {
    /// エラーコード（JSON-RPC コード、または HTTP ステータス）。
    public var code: Int
    /// 人間可読なメッセージ。
    public var message: String
    /// `@type` 付き詳細オブジェクト配列（ProtoJSON `Any` 表現）。
    public var details: [StructuredValue]

    public init(code: Int, message: String, details: [StructuredValue] = []) {
        self.code = code
        self.message = message
        self.details = details
    }

    // 標準 JSON-RPC コード
    public static let parseError = -32700
    public static let invalidRequest = -32600
    public static let methodNotFound = -32601
    public static let invalidParams = -32602
    public static let internalError = -32603

    // A2A 固有コード（仕様 §5.4）
    public static let taskNotFound = -32001
    public static let taskNotCancelable = -32002
    public static let pushNotificationNotSupported = -32003
    public static let unsupportedOperation = -32004
    public static let contentTypeNotSupported = -32005
    public static let invalidAgentResponse = -32006
    public static let extendedAgentCardNotConfigured = -32007
    public static let extensionSupportRequired = -32008
    public static let versionNotSupported = -32009

    /// `details` 内の `google.rpc.ErrorInfo.reason`（例 `TASK_NOT_FOUND`）。
    public var reason: String? {
        for detail in details {
            if case .object(let object) = detail,
               let reason = object["reason"]?.stringValue {
                return reason
            }
        }
        return nil
    }
}

extension A2AError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .rpc(let error):
            return "A2A error \(error.code): \(error.message)"
        case .http(let status, let body):
            return "HTTP error \(status): \(body ?? "no body")"
        case .emptyResult:
            return "Empty result from A2A server"
        case .invalidResponse(let detail):
            return "Invalid A2A response: \(detail)"
        case .decoding(let error):
            return "Failed to decode A2A response: \(error.localizedDescription)"
        case .encoding(let error):
            return "Failed to encode A2A request: \(error.localizedDescription)"
        case .timeout:
            return "Request timed out"
        case .transport(let error):
            return "Connection error: \(error.localizedDescription)"
        }
    }
}

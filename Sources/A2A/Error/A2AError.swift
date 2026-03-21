import Foundation

// MARK: - A2AError

/// A2Aクライアントエラー
public enum A2AError: Error, LocalizedError, Sendable {
    /// HTTP通信エラー
    case httpError(statusCode: Int, body: String?)

    /// JSON-RPCエラー
    case rpcError(JSONRPCError)

    /// 空の結果
    case emptyResult

    /// デコードエラー
    case decodingError(underlying: Error)

    /// エンコードエラー
    case encodingError(underlying: Error)

    /// ストリーミングエラー
    case streamingError(String)

    /// 無効なURL
    case invalidURL(String)

    /// タイムアウト
    case timeout

    /// 接続エラー
    case connectionError(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .httpError(let statusCode, let body):
            return "HTTP error \(statusCode): \(body ?? "no body")"
        case .rpcError(let error):
            return "JSON-RPC error \(error.code): \(error.message)"
        case .emptyResult:
            return "Empty result from A2A server"
        case .decodingError(let error):
            return "Failed to decode A2A response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode A2A request: \(error.localizedDescription)"
        case .streamingError(let message):
            return "Streaming error: \(message)"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .timeout:
            return "Request timed out"
        case .connectionError(let error):
            return "Connection error: \(error.localizedDescription)"
        }
    }
}

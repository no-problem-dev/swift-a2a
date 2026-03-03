import Foundation

// MARK: - JSONRPCId

/// JSON-RPC リクエストID
public enum JSONRPCId: Sendable, Equatable, Hashable {
    case string(String)
    case number(Int)
}

extension JSONRPCId: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let number = try? container.decode(Int.self) {
            self = .number(number)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "JSON-RPC id must be string or number"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        }
    }
}

// MARK: - JSONRPCRequest

/// JSON-RPC 2.0 リクエスト
public struct JSONRPCRequest<Params: Codable & Sendable>: Codable, Sendable {
    /// プロトコルバージョン（常に "2.0"）
    public let jsonrpc: String

    /// リクエストID
    public let id: JSONRPCId

    /// メソッド名
    public let method: String

    /// パラメータ
    public let params: Params?

    public init(id: JSONRPCId, method: String, params: Params? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }
}

// MARK: - JSONRPCResponse

/// JSON-RPC 2.0 レスポンス
public struct JSONRPCResponse<Result: Codable & Sendable>: Codable, Sendable {
    /// プロトコルバージョン（常に "2.0"）
    public let jsonrpc: String

    /// リクエストID
    public let id: JSONRPCId?

    /// 成功時の結果
    public let result: Result?

    /// エラー情報
    public let error: JSONRPCError?
}

// MARK: - JSONRPCError

/// JSON-RPC 2.0 エラー
public struct JSONRPCError: Codable, Sendable, Equatable {
    /// エラーコード
    public let code: Int

    /// エラーメッセージ
    public let message: String

    /// 追加データ
    public let data: AnyCodable?

    public init(code: Int, message: String, data: AnyCodable? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    // 標準エラーコード
    public static let parseError = -32700
    public static let invalidRequest = -32600
    public static let methodNotFound = -32601
    public static let invalidParams = -32602
    public static let internalError = -32603

    // A2A固有エラーコード
    public static let taskNotFound = -32001
    public static let taskNotCancelable = -32002
    public static let pushNotificationNotSupported = -32003
    public static let unsupportedOperation = -32004
    public static let contentTypeNotSupported = -32005
}

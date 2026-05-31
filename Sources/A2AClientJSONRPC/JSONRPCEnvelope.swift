import StructuredDataCore

/// JSON-RPC 2.0 リクエスト封筒。
struct JSONRPCRequest<Params: Encodable>: Encodable {
    let jsonrpc = "2.0"
    let id: String
    let method: String
    let params: Params?

    enum CodingKeys: String, CodingKey { case jsonrpc, id, method, params }
}

/// JSON-RPC 2.0 レスポンス封筒。
struct JSONRPCResponse<Result: Decodable>: Decodable {
    let jsonrpc: String?
    let id: JSONRPCID?
    let result: Result?
    let error: JSONRPCErrorObject?
}

/// JSON-RPC エラーオブジェクト（仕様 §9.5）。`data` は `@type` 付きオブジェクト配列。
struct JSONRPCErrorObject: Decodable {
    let code: Int
    let message: String
    let data: [StructuredValue]?
}

/// JSON-RPC の id（文字列または数値）。レスポンス側の許容のため両対応で復号。
enum JSONRPCID: Decodable {
    case string(String)
    case number(Int)

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .number(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "JSON-RPC id must be string or number")
        }
    }
}

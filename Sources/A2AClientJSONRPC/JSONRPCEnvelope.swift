import StructuredDataCore

/// The request envelope. The id is a fresh UUID per call and is not correlated on the way back.
struct JSONRPCRequest<Params: Encodable>: Encodable {
    let jsonrpc = "2.0"
    let id: String
    let method: String
    let params: Params?

    enum CodingKeys: String, CodingKey { case jsonrpc, id, method, params }
}

/// The response envelope. Exactly one of `result` and `error` is meaningful; both being absent
/// is what surfaces as an empty result.
struct JSONRPCResponse<Result: Decodable>: Decodable {
    let jsonrpc: String?
    let id: JSONRPCID?
    let result: Result?
    let error: JSONRPCErrorObject?
}

/// The error object (spec §9.5). Its `data` carries `@type`-tagged detail objects, which become
/// the remote error's details.
struct JSONRPCErrorObject: Decodable {
    let code: Int
    let message: String
    let data: [StructuredValue]?
}

/// A response id, which JSON-RPC allows to be either a string or a number. Decoded permissively
/// and then ignored — this client does not match responses against requests.
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

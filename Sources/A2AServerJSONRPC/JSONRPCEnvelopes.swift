import A2ACore

/// A request id: string, number or null. An id this decoder cannot read becomes null rather than
/// failing, so a malformed id still gets an answer.
enum JSONRPCID: Codable, Sendable, Hashable {
    case string(String)
    case number(Int)
    case null

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .number(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

struct JSONRPCMeta: Decodable {
    let id: JSONRPCID?
    let method: String?
}

struct JSONRPCParams<P: Decodable>: Decodable {
    let params: P?
}

struct JSONRPCSuccess<R: Encodable>: Encodable {
    let jsonrpc = "2.0"
    let id: JSONRPCID
    let result: R

    enum CodingKeys: String, CodingKey { case jsonrpc, id, result }
}

struct JSONRPCFailure: Encodable {
    let jsonrpc = "2.0"
    let id: JSONRPCID
    let error: JSONRPCErrorObject

    enum CodingKeys: String, CodingKey { case jsonrpc, id, error }
}

struct JSONRPCErrorObject: Encodable {
    let code: Int
    let message: String
}

/// The result for operations that return nothing: an empty object, since JSON-RPC requires a
/// result field on success.
struct EmptyResult: Encodable {}

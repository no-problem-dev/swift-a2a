import StructuredDataCore

/// HTTP+JSON / REST のエラー本体（`google.rpc.Status` JSON 表現。仕様 §11.6）。
struct RESTErrorEnvelope: Decodable {
    let error: RESTErrorBody?
}

struct RESTErrorBody: Decodable {
    let code: Int?
    let status: String?
    let message: String?
    let details: [StructuredValue]?
}

import StructuredDataCore

/// The REST error body: `google.rpc.Status` in its JSON form, nested under `error` (spec §11.6).
struct RESTErrorEnvelope: Decodable {
    let error: RESTErrorBody?
}

struct RESTErrorBody: Decodable {
    let code: Int?
    let status: String?
    let message: String?
    let details: [StructuredValue]?
}

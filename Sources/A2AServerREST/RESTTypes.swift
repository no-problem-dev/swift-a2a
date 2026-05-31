import Foundation

/// REST バインディングへの入力（HTTP フレームワーク非依存）。
public struct RESTRequest: Sendable {
    public var method: String
    /// クエリを除いたパス（例 `/tasks/abc:cancel`）。
    public var path: String
    public var query: [String: String]
    public var body: Data

    public init(method: String, path: String, query: [String: String] = [:], body: Data = Data()) {
        self.method = method
        self.path = path
        self.query = query
        self.body = body
    }
}

public struct RESTResponse: Sendable {
    public var status: Int
    public var body: Data
    public var contentType: String

    public init(status: Int, body: Data, contentType: String = "application/a2a+json") {
        self.status = status
        self.body = body
        self.contentType = contentType
    }
}

/// `stream` の各要素は封筒なしの `StreamResponse`（HTTP 層が SSE フレーミングする）。
public enum RESTOutcome: Sendable {
    case response(RESTResponse)
    case stream(AsyncThrowingStream<Data, Error>)
}

/// REST エラー本体（`google.rpc.Status` JSON 表現。仕様 §11.6）。
struct RESTErrorResponse: Encodable {
    let error: Body
    struct Body: Encodable {
        let code: Int
        let message: String
    }
}

import Foundation

/// One request, in the terms the dispatcher routes on, with no HTTP types involved.
public struct RESTRequest: Sendable {
    /// The HTTP method. Matched case-insensitively.
    public var method: String
    /// The path with the query removed, such as `/tasks/abc:cancel`. Leading and trailing slashes
    /// are ignored. Percent-encoded identifiers are decoded during routing.
    public var path: String
    /// The query parameters, already parsed and decoded.
    public var query: [String: String]
    /// The request body. Empty for methods that carry none.
    public var body: Data

    public init(method: String, path: String, query: [String: String] = [:], body: Data = Data()) {
        self.method = method
        self.path = path
        self.query = query
        self.body = body
    }
}

/// One response for the HTTP layer to write.
public struct RESTResponse: Sendable {
    /// The HTTP status. Errors carry the status their A2A code maps to.
    public var status: Int
    /// The JSON body.
    public var body: Data
    /// The media type to send, the A2A JSON type by default.
    public var contentType: String

    public init(status: Int, body: Data, contentType: String = "application/a2a+json") {
        self.status = status
        self.body = body
        self.contentType = contentType
    }
}

/// What a dispatched request produces: either one response, or a sequence of event bodies.
///
/// Streamed elements carry no envelope — each is a bare encoded event. The HTTP layer wraps them
/// in SSE frames and sets the event-stream content type itself, since the stream case carries no
/// `RESTResponse` to take it from.
public enum RESTOutcome: Sendable {
    /// One complete response.
    case response(RESTResponse)
    /// One encoded event per element.
    case stream(AsyncThrowingStream<Data, Error>)
}

/// The error body: `google.rpc.Status` in its JSON form, nested under `error` (spec §11.6).
struct RESTErrorResponse: Encodable {
    let error: Body
    struct Body: Encodable {
        let code: Int
        let message: String
    }
}

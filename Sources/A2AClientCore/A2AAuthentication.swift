import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// What the client sends to prove who it is.
///
/// Fixed for the life of a client: the credential is captured at construction and never refreshed,
/// so an expiring token means building a new client. Applied last when a request is assembled, so
/// these values win over any header set earlier.
public enum A2AAuthentication: Sendable {
    /// Send nothing.
    case none
    /// Send `Authorization: Bearer <token>`.
    case bearer(String)
    /// Send a key in a header of your choosing. Query and cookie placements are not supported here
    /// even though an agent card may advertise them.
    case apiKey(header: String, value: String)
    /// Send arbitrary headers, for schemes the cases above do not cover.
    case headers([String: String])

    /// Applies the credential to an outgoing request.
    func apply(to request: inout URLRequest) {
        switch self {
        case .none:
            break
        case .bearer(let token):
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case .apiKey(let header, let value):
            request.setValue(value, forHTTPHeaderField: header)
        case .headers(let headers):
            for (name, value) in headers {
                request.setValue(value, forHTTPHeaderField: name)
            }
        }
    }
}

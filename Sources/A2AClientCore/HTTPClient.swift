import Foundation
import A2ACore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The HTTP layer both remote bindings share: builds requests with the A2A headers and the
/// configured credential, and sends them buffered or as a byte stream.
///
/// Each instance owns its own `URLSession`, so two clients never share a connection pool.
public struct HTTPClient: Sendable {
    public let configuration: A2AClientConfiguration
    private let session: URLSession

    public init(configuration: A2AClientConfiguration, sessionConfiguration: URLSessionConfiguration? = nil) {
        self.configuration = configuration
        let sessionConfig = sessionConfiguration ?? URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        self.session = URLSession(configuration: sessionConfig)
    }

    /// Builds a request carrying the protocol version, any opted-in extensions, and the credential.
    ///
    /// - Parameters:
    ///   - url: Where to send it.
    ///   - method: The HTTP method.
    ///   - contentType: The request body's media type, if there is a body.
    ///   - accept: What the caller will take back.
    ///   - body: The request body.
    ///   - streaming: Whether to apply the longer streaming timeout instead of the normal one.
    public func makeRequest(
        url: URL,
        method: String,
        contentType: String? = nil,
        accept: String? = nil,
        body: Data? = nil,
        streaming: Bool = false
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = streaming ? configuration.streamTimeout : configuration.timeout
        if let contentType { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        if let accept { request.setValue(accept, forHTTPHeaderField: "Accept") }
        request.setValue(A2AProtocol.version, forHTTPHeaderField: A2AProtocol.versionHeader)
        if !configuration.extensions.isEmpty {
            request.setValue(
                configuration.extensions.joined(separator: ","),
                forHTTPHeaderField: A2AProtocol.extensionsHeader
            )
        }
        configuration.authentication.apply(to: &request)
        return request
    }

    /// Sends a request and returns the whole body.
    ///
    /// The status is not checked — a 4xx or 5xx comes back as data, because the bindings need to
    /// read the error body before deciding what to throw.
    ///
    /// - Throws: `A2AError.timeout` on expiry, `A2AError.transport` on any other connection
    ///   failure, `A2AError.invalidResponse` if the response is not HTTP.
    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw A2AError.invalidResponse("Not an HTTP response")
            }
            return (data, http)
        } catch let error as A2AError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw A2AError.timeout
        } catch {
            throw A2AError.transport(error)
        }
    }

    /// Starts a streaming request and returns its bytes as they arrive.
    ///
    /// Returns as soon as the response head is available, so the status can be checked before the
    /// body is consumed. Same error mapping as `send(_:)`.
    public func stream(_ request: URLRequest) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw A2AError.invalidResponse("Not an HTTP response")
            }
            return (bytes, http)
        } catch let error as A2AError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw A2AError.timeout
        } catch {
            throw A2AError.transport(error)
        }
    }
}

import Foundation
import A2ACore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The body of a streaming response, handed over in the chunks the transport delivers.
public typealias HTTPResponseBody = AsyncThrowingStream<Data, any Error>

/// The HTTP layer both remote bindings share: builds requests with the A2A headers and the
/// configured credential, and sends them buffered or as a byte stream.
///
/// Each instance owns its own `URLSession`, so two clients never share a connection pool.
public struct HTTPClient: Sendable {
    public let configuration: A2AClientConfiguration
    private let session: URLSession
    private let streamingBodies: StreamingBodyDelegate

    public init(configuration: A2AClientConfiguration, sessionConfiguration: URLSessionConfiguration? = nil) {
        self.configuration = configuration
        let sessionConfig = sessionConfiguration ?? URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        let streamingBodies = StreamingBodyDelegate()
        self.streamingBodies = streamingBodies
        self.session = URLSession(configuration: sessionConfig, delegate: streamingBodies, delegateQueue: nil)
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

    /// Starts a streaming request and returns its body chunks as they arrive.
    ///
    /// Returns as soon as the response head is available, so the status can be checked before the
    /// body is consumed. Same error mapping as `send(_:)`.
    ///
    /// The body is driven by `URLSessionDataDelegate` rather than `URLSession.bytes(for:)`, which
    /// exists only on Apple platforms. Abandoning the returned stream cancels the request.
    public func stream(_ request: URLRequest) async throws -> (HTTPResponseBody, HTTPURLResponse) {
        do {
            let (response, body) = try await streamingBodies.start(session.dataTask(with: request))
            guard let http = response as? HTTPURLResponse else {
                throw A2AError.invalidResponse("Not an HTTP response")
            }
            return (body, http)
        } catch let error as A2AError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw A2AError.timeout
        } catch {
            throw A2AError.transport(error)
        }
    }
}

/// Holds the streaming requests in flight, so each one's delegate callbacks reach the caller that
/// started it: the response head resumes an awaiting continuation, and every body chunk after it
/// is yielded to that request's stream.
///
/// A `URLSession` takes one delegate for all of its tasks, and this session also serves the
/// buffered `send(_:)` path. Tasks that were never registered here are let through untouched.
private final class StreamingBodyDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private struct InFlight {
        var head: CheckedContinuation<URLResponse, any Error>?
        let body: HTTPResponseBody.Continuation
    }

    private let lock = NSLock()
    private var inFlight: [Int: InFlight] = [:]

    /// Resumes once the response head has arrived, handing back the head and the body still to come.
    func start(_ task: URLSessionDataTask) async throws -> (URLResponse, HTTPResponseBody) {
        let (body, bodyContinuation) = HTTPResponseBody.makeStream()
        bodyContinuation.onTermination = { [weak task] reason in
            if case .cancelled = reason { task?.cancel() }
        }

        let identifier = task.taskIdentifier
        let response = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (head: CheckedContinuation<URLResponse, any Error>) in
                lock.withLock { inFlight[identifier] = InFlight(head: head, body: bodyContinuation) }
                task.resume()
            }
        } onCancel: {
            task.cancel()
        }
        return (response, body)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        let head = lock.withLock { () -> CheckedContinuation<URLResponse, any Error>? in
            guard let head = inFlight[dataTask.taskIdentifier]?.head else { return nil }
            inFlight[dataTask.taskIdentifier]?.head = nil
            return head
        }
        head?.resume(returning: response)
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let body = lock.withLock { inFlight[dataTask.taskIdentifier]?.body }
        body?.yield(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard let finished = lock.withLock({ inFlight.removeValue(forKey: task.taskIdentifier) }) else { return }

        if let head = finished.head {
            head.resume(throwing: error ?? A2AError.invalidResponse("The response ended before its head arrived"))
            finished.body.finish()
            return
        }
        finished.body.finish(throwing: error)
    }
}

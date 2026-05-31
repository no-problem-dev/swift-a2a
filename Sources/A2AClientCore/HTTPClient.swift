import Foundation
import A2ACore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// バインディング横断の HTTP 基盤。認証・A2A ヘッダ付与・送信・SSE ストリームを提供します。
public struct HTTPClient: Sendable {
    public let configuration: A2AClientConfiguration
    private let session: URLSession

    public init(configuration: A2AClientConfiguration, sessionConfiguration: URLSessionConfiguration? = nil) {
        self.configuration = configuration
        let sessionConfig = sessionConfiguration ?? URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        self.session = URLSession(configuration: sessionConfig)
    }

    /// リクエストを構築（認証・`A2A-Version`・`A2A-Extensions` 付与）。
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

    /// リクエストを送信し、本文と HTTP 応答を返す。ステータス検証は呼び出し側が行う。
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

    /// SSE ストリームを開始し、行バイトストリームと HTTP 応答を返す。
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

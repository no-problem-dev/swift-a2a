import Foundation
import A2ACore
import A2AClientCore
import A2AServer

extension A2AClient {
    /// Creates a client wired straight to a handler in this process, with no HTTP and no
    /// serialization.
    ///
    /// The base URL is a placeholder that is never dialled, so `fetchAgentCard()` — which always
    /// goes over HTTP — does not work on such a client. Fetch the card from the handler's own
    /// configuration instead.
    ///
    /// - Parameters:
    ///   - handler: The server-side handler to call directly.
    ///   - context: The call context every operation is invoked with. Fixed for the life of the
    ///     client, so per-call identity needs a separate client.
    public static func inProcess(
        handler: any RequestHandler,
        context: ServerCallContext = ServerCallContext()
    ) -> A2AClient {
        let configuration = A2AClientConfiguration(baseURL: URL(string: "inprocess://local")!)
        let transport = InProcessTransport(handler: handler, context: context)
        return A2AClient(transport: transport, http: HTTPClient(configuration: configuration), configuration: configuration)
    }
}

import Foundation
import A2ACore
import A2AClientCore
import A2AServer

extension A2AClient {
    /// 同一プロセス内の `RequestHandler` に直結した A2A クライアントを生成（HTTP を介さない）。
    public static func inProcess(
        handler: any RequestHandler,
        context: ServerCallContext = ServerCallContext()
    ) -> A2AClient {
        let configuration = A2AClientConfiguration(baseURL: URL(string: "inprocess://local")!)
        let transport = InProcessTransport(handler: handler, context: context)
        return A2AClient(transport: transport, http: HTTPClient(configuration: configuration), configuration: configuration)
    }
}

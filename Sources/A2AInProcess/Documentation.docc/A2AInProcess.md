# ``A2AInProcess``

インプロセス A2A バインディング — `A2AClient` を同一プロセス内の `RequestHandler` へ直結し、HTTP とシリアライズのオーバーヘッドをゼロにする。

## Overview

`A2AInProcess` はテストおよびエージェントを同一バイナリ内に組み込む用途向け。このモジュールを import すると `A2ACore`・`A2AClientCore`・`A2AServer` が再エクスポートされるため、1 つの import でフルスタックが利用可能になる。

`A2AClient.inProcess(handler:context:)` ファクトリを呼び出して ``InProcessTransport`` を内部に持つクライアントを生成する。このトランスポートは各操作を JSON にシリアライズしたりネットワークソケットを開いたりせず、`RequestHandler` へ直接転送する。ラウンドトリップのレイテンシが無視できるほど小さくなり、テスト出力が決定論的になる。

```swift
import A2ACore
import A2AServer
import A2AInProcess

// サーバフレームワークでハンドラを構築
let card = AgentCard(
    name: "Echo Agent",
    description: "入力をそのまま返すエージェント。",
    supportedInterfaces: [AgentInterface(url: "inprocess://local", protocolBinding: "JSONRPC")],
    version: "1.0",
    capabilities: AgentCapabilities()
)
let handler = DefaultRequestHandler(agentCard: card, executor: EchoExecutor())

// HTTP を介さずクライアントをハンドラへ直結
let client = A2AClient.inProcess(handler: handler)

let response = try await client.sendMessage(Message.user("こんにちは！"))
if case .task(let task) = response {
    print("タスク状態:", task.status.state)
}
```

テスト中に認証情報や他のコール毎メタデータを注入する必要がある場合は、`inProcess(handler:context:)` にカスタムの `ServerCallContext` を渡す。

## Topics

### トランスポート

- ``InProcessTransport``

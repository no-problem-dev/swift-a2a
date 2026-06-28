# ``A2AServerJSONRPC``

A2A プロトコルの JSON-RPC 2.0 サーバ側ディスパッチャ — JSON-RPC 封筒をデコードし `RequestHandler` へディスパッチして、レスポンスを生バイト列にエンコードして返す。

## Overview

`A2AServerJSONRPC` は HTTP サーバとトランスポート非依存の `A2AServer` フレームワークの間に位置する薄いプロトコル変換層。意図的に HTTP ライブラリ非依存で設計されており、`Data` ブロブを受け取り ``JSONRPCOutcome`` を返す。`JSONRPCOutcome` は単一の ``JSONRPCOutcome/unary(_:)`` `Data` 値か、SSE フレームごとに 1 つの ``JSONRPCOutcome/stream(_:)`` `Data` 値のストリームのいずれか。そのバイト列をレスポンスボディへ書き込む責任は HTTP フレームワーク側にある。

任意の `RequestHandler` を使って ``JSONRPCHandler`` を生成し、受信リクエストごとに ``JSONRPCHandler/handle(_:context:)`` を呼び出す。ハンドラは `method` フィールド（例: `SendMessage`・`GetTask`・`SubscribeToTask`）でルーティングし、対応する `RequestHandler` メソッドへ委譲。結果を標準の `{jsonrpc: "2.0", id, result}` 封筒にラップしてエンコードしたバイト列を返す:

```swift
import A2ACore
import A2AServer
import A2AServerJSONRPC

// A2AServer の任意の RequestHandler と組み合わせる
let handler = DefaultRequestHandler(agentCard: card, executor: myExecutor)
let rpcHandler = JSONRPCHandler(handler: handler)

// HTTP ルートハンドラ内（疑似コード）:
let requestData: Data = httpRequest.body
let outcome = await rpcHandler.handle(requestData)

switch outcome {
case .unary(let data):
    httpResponse.write(data)
case .stream(let events):
    for try await chunk in events {
        httpResponse.writeSSEFrame(chunk)
    }
}
```

## Topics

### ディスパッチング

- ``JSONRPCHandler``
- ``JSONRPCOutcome``

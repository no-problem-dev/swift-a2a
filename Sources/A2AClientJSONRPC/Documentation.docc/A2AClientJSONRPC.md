# ``A2AClientJSONRPC``

A2A クライアントの JSON-RPC 2.0 バインディング — `A2AClient.jsonRPC(endpoint:)` ファクトリと内部の `JSONRPCTransport` を追加する。

## Overview

`A2AClientJSONRPC` は A2A 仕様 §9 の JSON-RPC バインディングを実装する。REST バインディングの `A2AClientREST` と同様に、このモジュールを import すると完全な `A2AClient` ファサードと `A2ACore` データモデルが再エクスポートされるため、追加の import は不要。

`A2AClient.jsonRPC(endpoint:authentication:)` ファクトリを呼び出してクライアントを生成する。内部では ``JSONRPCTransport`` が共有の `A2AClient` ファサードと組み合わされる。このトランスポートは `SendMessage`・`GetTask`・`SubscribeToTask` などのメソッド名で単一エンドポイント URL へすべてのリクエストを POST する。

```swift
import A2AClientJSONRPC

let client = A2AClient.jsonRPC(
    endpoint: URL(string: "https://agent.example.com/rpc")!,
    authentication: .bearer("my-token")
)

// 既知のタスクを ID で取得
let task = try await client.getTask(TaskID("abc-123"))
print("状態:", task.status.state)

// 実行中タスクの更新を購読
let updates = try await client.subscribeToTask(TaskID("abc-123"))
for try await event in updates {
    print(event)
}
```

``JSONRPCTransport`` は public 型として公開されており、独自の `HTTPClient` と組み合わせることもできる。

## Topics

### トランスポート

- ``JSONRPCTransport``

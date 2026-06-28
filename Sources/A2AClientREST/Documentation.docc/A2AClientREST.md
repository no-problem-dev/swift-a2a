# ``A2AClientREST``

A2A クライアントの HTTP+JSON REST バインディング — `A2AClient.rest(baseURL:)` ファクトリと内部の `RESTTransport` を追加する。

## Overview

`A2AClientREST` は A2A 仕様 §11 の REST バインディングを実装する。このモジュールを import すると、`A2AClientCore` から再エクスポートされる完全な `A2AClient` ファサードと `A2ACore` データモデルが利用可能になるため、リクエスト送信に必要な import は 1 つで足りる。

`A2AClient.rest(baseURL:authentication:)` ファクトリを呼び出してクライアントを生成する。内部では ``RESTTransport`` が共有の `A2AClient` ファサードと組み合わされる。このトランスポートは各 A2A 操作を個別の HTTP パス（`/message:send`・`/tasks/{id}`・`/tasks/{id}:cancel` 等）にマップし、ストリーミング応答には Server-Sent Events を使用する。

```swift
import A2AClientREST

let client = A2AClient.rest(
    baseURL: URL(string: "https://agent.example.com")!,
    authentication: .bearer("my-token")
)

// 非ストリーミング: タスクまたは即時メッセージ返信を取得
let response = try await client.sendMessage(Message.user("こんにちは！"))

// ストリーミング: TaskStatusUpdateEvent と TaskArtifactUpdateEvent を順次受信
let stream = try await client.streamMessage(Message.user("バックグラウンドで処理して。"))
for try await event in stream {
    print(event)
}
```

``RESTTransport`` は public 型として公開されており、`A2AAuthentication` の範囲を超えた接続動作のカスタマイズやミドルウェア追加が必要な場合は独自の `HTTPClient` と組み合わせることもできる。

## Topics

### トランスポート

- ``RESTTransport``

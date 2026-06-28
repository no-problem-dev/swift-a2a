# ``A2AServerREST``

A2A プロトコルの REST サーバ側ディスパッチャ — HTTP メソッドとパスを `RequestHandler` へルーティングし、HTTP フレームワークがワイヤへ書き込む型付きリクエスト/レスポンス値を返す。

## Overview

`A2AServerREST` は A2A 仕様 §11 の HTTP+JSON REST バインディング向けトランスポート変換層。`A2AServerJSONRPC` と同様に HTTP ライブラリ非依存で設計されており、``RESTRequest``（HTTP メソッド・パス・クエリパラメータ・生ボディバイト列）を受け取り、単一レスポンスの ``RESTOutcome/response(_:)`` か SSE 用生イベント `Data` 値のストリーム ``RESTOutcome/stream(_:)`` を返す。

`A2AServer` の任意の `RequestHandler` を使って ``RESTHandler`` を生成する。ハンドラは `POST /message:send`・`GET /tasks/{id}`・`POST /tasks/{id}:cancel`・`GET /extendedAgentCard` などのパスをマッチさせ、対応する `RequestHandler` メソッドに委譲して結果を JSON バイト列にエンコードして返す:

```swift
import A2ACore
import A2AServer
import A2AServerREST

let handler = DefaultRequestHandler(agentCard: card, executor: myExecutor)
let restHandler = RESTHandler(handler: handler)

// HTTP ルートハンドラ内（疑似コード）:
let request = RESTRequest(
    method: "POST",
    path: "/message:send",
    query: [:],
    body: httpRequest.body
)
let outcome = await restHandler.handle(request)

switch outcome {
case .response(let resp):
    httpResponse.status = resp.status
    httpResponse.write(resp.body)
case .stream(let events):
    for try await chunk in events {
        httpResponse.writeSSEFrame(chunk)
    }
}
```

## Topics

### ディスパッチング

- ``RESTHandler``
- ``RESTRequest``
- ``RESTResponse``
- ``RESTOutcome``

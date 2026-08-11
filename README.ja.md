# swift-a2a

[English](./README.md) | 日本語

[A2A (Agent2Agent) プロトコル](https://a2a-protocol.org/latest/) の Swift 実装。クライアント・サーバー・テスト用の in-process バインディングを含む。

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![A2A](https://img.shields.io/badge/A2A-v1.0.1-green.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017+%20%7C%20macOS%2014+%20%7C%20tvOS%2017+%20%7C%20watchOS%2010+%20%7C%20visionOS%201+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## 特徴

- **2 つのバインディング、1 つの API** — REST（HTTP+JSON、仕様 §11）と JSON-RPC 2.0（§9）。仕様が機能的等価を要求しているので、エージェントのカードが載せている方を選ぶだけで、他のコードは変わらない
- **ワイヤ形式は正規の Protocol Buffer 定義から** — `ROLE_USER` 形式の enum 名、camelCase フィールド、判別子レス oneof、RFC 3339 タイムスタンプ
- **サーバーは 1 つの型を書くだけ** — `AgentExecutor` に適合させて `DefaultRequestHandler` に渡し、トランスポート非依存のディスパッチャ経由で公開する
- **ネットワーク無しでテストできる** — `A2AClient.inProcess(handler:)` がクライアントをハンドラに直結する。HTTP もシリアライズも通らない
- **SSE ストリーミング** — `message:stream` と `tasks:subscribe`。イベント境界を取りこぼさないパーサー付き
- **型安全で Swift らしい** — oneof は enum、ID は型付き、メッセージ構築は `@resultBuilder`
- **依存は 2 つだけ** — Foundation と [swift-structured-data](https://github.com/no-problem-dev/swift-structured-data)。gRPC・swift-syntax・マクロは使わない

## クイックスタート

```swift
import A2AClientREST   // または A2AClientJSONRPC

let client = A2AClient.rest(
    baseURL: URL(string: "https://agent.example.com/a2a/v1")!,
    authentication: .bearer("your-token")
)

let response = try await client.sendMessage(.user("売上レポートを作って"))

switch response {
case .task(let task):
    print(task.status.state)
    print(task.artifacts.first?.parts.first?.text ?? "")
case .message(let message):
    print(message.text)
}
```

ストリーミング・タスク操作・プッシュ通知設定・サーバー側はドキュメントを参照。

## ドキュメント

ライブラリごとに DocC ページがある：

- [A2ACore](https://no-problem-dev.github.io/swift-a2a/documentation/a2acore/) — データモデルとその符号化
- [A2AClientREST](https://no-problem-dev.github.io/swift-a2a/documentation/a2aclientrest/) · [A2AClientJSONRPC](https://no-problem-dev.github.io/swift-a2a/documentation/a2aclientjsonrpc/) — 2 つのクライアントバインディング
- [A2AServer](https://no-problem-dev.github.io/swift-a2a/documentation/a2aserver/) — エージェントの実装とホスティング
- [A2AServerREST](https://no-problem-dev.github.io/swift-a2a/documentation/a2aserverrest/) · [A2AServerJSONRPC](https://no-problem-dev.github.io/swift-a2a/documentation/a2aserverjsonrpc/) — サーバー側ディスパッチャ
- [A2AInProcess](https://no-problem-dev.github.io/swift-a2a/documentation/a2ainprocess/) — ネットワーク無しのテスト

## インストール

`Package.swift` に追加する：

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-a2a.git", from: "0.3.0")
]
```

必要な product をターゲットに足す。エージェントを呼ぶならクライアント側、ホストするならサーバー側：

```swift
.target(name: "YourTarget", dependencies: [
    .product(name: "A2AClientREST", package: "swift-a2a"),
    // .product(name: "A2AClientJSONRPC", package: "swift-a2a"),
])
```

## 動作環境

| swift-a2a | Swift | プラットフォーム |
|---|---|---|
| 0.x | 6.2+ | iOS 17+ · macOS 14+ · tvOS 17+ · watchOS 10+ · visionOS 1+ |

実装している A2A のリビジョンは 1.0.1。gRPC バインディングは未実装。

## ライセンス

MIT。[LICENSE](LICENSE) を参照。

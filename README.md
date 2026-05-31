[English](README_EN.md) | 日本語

# swift-a2a

[A2A (Agent2Agent) プロトコル](https://a2a-protocol.org/latest/) **v1.0** の Swift クライアント実装。

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![A2A](https://img.shields.io/badge/A2A-v1.0.1-green.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017+%20%7C%20macOS%2014+%20%7C%20tvOS%2017+%20%7C%20watchOS%2010+%20%7C%20visionOS%201+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## 特徴

- **A2A v1.0 完全準拠** — 正規 Protocol Buffer 定義に基づく ProtoJSON シリアライズ（`ROLE_USER` 形式の enum、camelCase、判別子レス oneof）
- **2 バインディング** — **REST（HTTP+JSON）** と **JSON-RPC 2.0** を提供。両者は機能的に等価（仕様 §5.1）で、エージェントが対応する方を選べる
- **層をターゲットで分離** — 規定プロトコルの型だけ使う `A2ACore`、実装を使う `A2AClientREST` / `A2AClientJSONRPC`。アンブレラなし、依存は使う層だけが背負う
- **SSE ストリーミング** — `message:stream` / `tasks:subscribe` をリアルタイム受信
- **型安全 & Swift らしい設計** — oneof を enum、型付き ID、`@resultBuilder` でメッセージ構築
- **依存最小** — Foundation + [swift-structured-data](https://github.com/no-problem-dev/swift-structured-data) のみ。gRPC・swift-syntax・マクロ非依存

## アーキテクチャ

| Product | 役割 | 依存 |
|---|---|---|
| `A2ACore` | 規定プロトコル層: 全ワイヤ型 + ProtoJSON Codable + 構築ビルダー | StructuredDataCore |
| `A2AClientREST` | REST（HTTP+JSON）バインディングのクライアント | A2ACore |
| `A2AClientJSONRPC` | JSON-RPC 2.0 バインディングのクライアント | A2ACore |

サーバ実装などで型だけ欲しいときは `A2ACore` のみを import します。クライアントは使うバインディングの product を import します（両方入れて Agent Card から選択することも可能）。

## インストール

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-a2a.git", from: "0.3.0")
]
```

```swift
.target(name: "YourTarget", dependencies: [
    .product(name: "A2AClientREST", package: "swift-a2a"),      // REST を使う場合
    // .product(name: "A2AClientJSONRPC", package: "swift-a2a"), // JSON-RPC を使う場合
])
```

## クイックスタート

### クライアント生成

```swift
import A2ACore
import A2AClientREST   // または A2AClientJSONRPC

// REST バインディング
let client = A2AClient.rest(
    baseURL: URL(string: "https://agent.example.com/a2a/v1")!,
    authentication: .bearer("your-token")
)

// JSON-RPC バインディング
// let client = A2AClient.jsonRPC(
//     endpoint: URL(string: "https://agent.example.com/rpc")!,
//     authentication: .bearer("your-token")
// )
```

### Agent Card の取得

```swift
let card = try await client.fetchAgentCard()   // /.well-known/agent-card.json
print(card.name)
print(card.capabilities.streaming ?? false)
print(card.supportedInterfaces.map(\.protocolBinding))   // ["JSONRPC", "GRPC", "HTTP+JSON"]
```

### メッセージ送信

```swift
let response = try await client.sendMessage(.user("売上レポートを作成して"))

switch response {
case .task(let task):
    print(task.status.state)        // .completed など
    print(task.artifacts.first?.parts.first?.text ?? "")
case .message(let message):
    print(message.text)
}
```

ビルダーで複数パートのメッセージも組み立てられます（文字列リテラルは自動でテキストパート）:

```swift
let message = Message(role: .user) {
    "この画像を解析して"
    Part.file(uri: "https://example.com/photo.png", mediaType: "image/png")
    Part.data(["threshold": 0.8])
}
let response = try await client.sendMessage(message)
```

### ストリーミング

```swift
for try await event in try await client.streamMessage(.user("詳細なレポートを書いて")) {
    switch event {
    case .task(let task): print("task: \(task.status.state)")
    case .statusUpdate(let update): print("status: \(update.status.state)")
    case .artifactUpdate(let update): print("artifact chunk: \(update.artifact.parts.first?.text ?? "")")
    case .message(let message): print("message: \(message.text)")
    }
}
```

### タスク操作

```swift
let task = try await client.getTask("task-id", historyLength: 10)
let canceled = try await client.cancelTask("task-id")
let list = try await client.listTasks(ListTasksRequest(status: .working))
for try await event in try await client.subscribeToTask("task-id") { /* ... */ }
```

### プッシュ通知設定

```swift
let config = try await client.createPushNotificationConfig(
    TaskPushNotificationConfig(url: "https://my-webhook.example.com/a2a", taskId: "task-id")
)
let configs = try await client.listPushNotificationConfigs(taskId: "task-id")
try await client.deletePushNotificationConfig(taskId: "task-id", id: config.id ?? "")
```

## エラーハンドリング

```swift
do {
    _ = try await client.getTask("missing")
} catch let A2AError.rpc(error) {
    print(error.code)     // -32001
    print(error.reason)   // "TASK_NOT_FOUND"（google.rpc.ErrorInfo より）
} catch let A2AError.http(status, body) {
    print(status, body ?? "")
}
```

## 対応操作

| 操作 | メソッド | JSON-RPC | REST |
|---|---|---|---|
| メッセージ送信 | `sendMessage` | `SendMessage` | `POST /message:send` |
| ストリーミング送信 | `streamMessage` | `SendStreamingMessage` | `POST /message:stream` |
| タスク取得 | `getTask` | `GetTask` | `GET /tasks/{id}` |
| タスク一覧 | `listTasks` | `ListTasks` | `GET /tasks` |
| タスクキャンセル | `cancelTask` | `CancelTask` | `POST /tasks/{id}:cancel` |
| タスク購読 | `subscribeToTask` | `SubscribeToTask` | `POST /tasks/{id}:subscribe` |
| プッシュ設定 作成/取得/一覧/削除 | `*PushNotificationConfig` | `*TaskPushNotificationConfig` | `/tasks/{id}/pushNotificationConfigs` |
| 拡張 Agent Card | `fetchExtendedAgentCard` | `GetExtendedAgentCard` | `GET /extendedAgentCard` |

## ライセンス

MIT

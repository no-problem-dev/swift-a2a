[English](README_EN.md) | 日本語

# swift-a2a

Google A2A (Agent-to-Agent) プロトコルの Swift クライアント実装

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017.0+%20%7C%20macOS%2014.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## 特徴

- **A2A プロトコル準拠** - [Agent-to-Agent Protocol](https://a2a-protocol.org/) (JSON-RPC 2.0) のフル実装
- **SSE ストリーミング** - Server-Sent Events によるリアルタイムタスク状態・アーティファクト更新
- **Agent Card** - `/.well-known/agent.json` の自動取得でエージェント能力を検出
- **柔軟な認証** - Bearer / API Key / カスタムヘッダー / OAuth2 をサポート
- **Swift Concurrency** - Actor ベースの完全な async/await + Sendable 設計
- **依存ゼロ** - Foundation のみで動作、サードパーティ依存なし

## インストール

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-a2a.git", from: "0.1.0")
]
```

```swift
.target(name: "YourTarget", dependencies: [
    .product(name: "A2A", package: "swift-a2a"),
])
```

## クイックスタート

### エージェントの情報を取得

```swift
import A2A

let client = A2AClient(configuration: .init(
    baseURL: URL(string: "https://agent.example.com")!,
    authentication: .bearer("your-token")
))

// Agent Card を取得してエージェントの能力を確認
let card = try await client.fetchAgentCard()
print(card.name)            // エージェント名
print(card.skills)          // 対応スキル一覧
print(card.capabilities)    // ストリーミング対応等
```

### メッセージの送信

```swift
// テキストメッセージを送信
let task = try await client.sendMessage(
    Message(role: .user, parts: [.text(TextPart(text: "売上レポートを作成して"))])
)
print(task.status.state)    // .completed, .working, etc.

// アーティファクト（生成物）を取得
for artifact in task.artifacts ?? [] {
    for part in artifact.parts {
        switch part {
        case .text(let text): print(text.text)
        case .file(let file): print(file.file.name)
        case .data(let data): print(data.data)
        }
    }
}
```

### ストリーミング

```swift
// SSE ストリーミングでリアルタイムに受信
let stream = try await client.streamMessage(
    Message(role: .user, parts: [.text(TextPart(text: "長文レポートを生成して"))])
)

for try await event in stream {
    switch event {
    case .statusUpdate(let update):
        print("状態: \(update.status.state)")
    case .artifactUpdate(let update):
        print("アーティファクト: \(update.artifact.name ?? "")")
    }
}
```

### タスク管理

```swift
// タスク ID で後から状態を確認
let task = try await client.getTask(id: "task-123")

// タスクをキャンセル
let canceled = try await client.cancelTask(id: "task-123")
```

## API 概要

### クライアント

| メソッド | 説明 |
|---------|------|
| `fetchAgentCard()` | Agent Card を取得（`/.well-known/agent.json`） |
| `sendMessage(_:configuration:)` | メッセージを同期送信 |
| `streamMessage(_:configuration:)` | メッセージを SSE ストリーミング送信 |
| `getTask(id:historyLength:)` | タスク ID で状態取得 |
| `cancelTask(id:)` | タスクをキャンセル |

### 認証方式

| 方式 | 用途 |
|------|------|
| `.bearer(String)` | Bearer トークン認証 |
| `.apiKey(headerName:value:)` | カスタムヘッダーによる API キー |
| `.headers([String: String])` | 任意のカスタムヘッダー |
| `.none` | 認証なし |

### メッセージ Part

| Part | 内容 |
|------|------|
| `.text(TextPart)` | テキストデータ |
| `.file(FilePart)` | ファイル（バイナリ or URI） |
| `.data(DataPart)` | 任意の構造化データ |

### タスク状態

`submitted` → `working` → `completed` / `failed` / `canceled` / `input-required` / `auth-required`

## A2A プロトコルについて

A2A (Agent-to-Agent) は Google が提唱し [Linux Foundation](https://www.linuxfoundation.org/) がホストするオープンプロトコルです。異なるフレームワーク・ベンダーで構築された AI エージェント同士の相互運用を実現します。

- **MCP** がエージェント ↔ ツール/データ の接続（縦の統合）を担うのに対し
- **A2A** はエージェント ↔ エージェント の連携（横の統合）を担います

両者は補完関係にあり、組み合わせることで外部ツールも外部エージェントも統一的に扱えます。

## 要件

- iOS 17.0+ / macOS 14.0+
- Swift 6.2+
- Xcode 16.0+

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照

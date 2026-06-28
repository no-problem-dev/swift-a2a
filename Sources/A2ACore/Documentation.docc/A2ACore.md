# ``A2ACore``

A2A プロトコルの Swift 実装 — swift-a2a パッケージ全モジュールが共有するデータモデル・操作型・プロトコル定数。

## Overview

swift-a2a は Google の Agent-to-Agent（A2A）プロトコル（v1.0.1）をモジュール形式で実装した Swift ライブラリ。必要な層だけを導入できるよう 7 つのライブラリに分割されており、``A2ACore`` はその共有基盤。タスク・メッセージ・パート・アーティファクト・Agent Card からなる完全な A2A データモデル、操作リクエスト／レスポンス型全種、ストリームイベント型、JSON コーデックを定義する。他のすべてのライブラリは ``A2ACore`` に依存する。

クライアント側ライブラリ `A2AClientREST` と `A2AClientJSONRPC` はそれぞれ、共有の `A2AClient` ファサードに具体的なトランスポートバインディングを組み合わせる。`A2AClientREST` は HTTP+JSON REST バインディング（仕様 §11）、`A2AClientJSONRPC` は JSON-RPC 2.0 バインディング（仕様 §9）を使用する。両モジュールは ``A2ACore`` を再エクスポートするため、1 つの import 文でメッセージの構築・送信に必要なものがすべて揃う。

サーバ側は 3 つの補完ライブラリで構成される。`A2AServer` はトランスポート非依存フレームワークを提供し、`AgentExecutor` と `RequestHandler` プロトコル、ライフサイクル管理を担う `TaskManager` actor、プロトタイピング向けのインメモリストア実装を含む。`A2AServerREST` と `A2AServerJSONRPC` はそれぞれ、生バイト列を `RequestHandler` 呼び出しに変換する薄い HTTP 非依存ディスパッチャを追加する。最後に `A2AInProcess` は、`A2AClient` を同一プロセス内の `RequestHandler` へ直結させ、ネットワーク通信なしに動作させる。これにより実際のエージェント実装に対してユニットテストを書くのが容易になる。

次の例では ``Message/user(_:messageId:)`` でテキストメッセージを作成し、REST クライアントを通じてリモートエージェントの結果を検査する:

```swift
import A2ACore
import A2AClientREST

let client = A2AClient.rest(baseURL: URL(string: "https://agent.example.com")!)

let message = Message.user("添付ドキュメントを要約して。")
let response = try await client.sendMessage(message)

switch response {
case .task(let task):
    print("タスク作成:", task.id.rawValue, "状態:", task.status.state)
case .message(let reply):
    print("即時返信:", reply.text)
}
```

## Topics

### プロトコル定数

- ``A2AProtocol``

### データモデル — タスク

- ``A2ATask``
- ``TaskStatus``
- ``TaskState``
- ``TaskID``
- ``ContextID``

### データモデル — メッセージとパート

- ``Message``
- ``Part``
- ``PartBuilder``
- ``Role``
- ``MessageID``

### データモデル — アーティファクト

- ``Artifact``
- ``ArtifactID``

### データモデル — Agent Card

- ``AgentCard``
- ``AgentSkill``
- ``AgentCapabilities``
- ``AgentProvider``
- ``AgentInterface``
- ``AgentExtension``
- ``AgentCardSignature``

### データモデル — セキュリティスキーム

- ``SecurityScheme``
- ``APIKeySecurityScheme``
- ``HTTPAuthSecurityScheme``
- ``OAuth2SecurityScheme``
- ``OpenIdConnectSecurityScheme``
- ``MutualTLSSecurityScheme``
- ``OAuthFlows``
- ``AuthorizationCodeOAuthFlow``
- ``ClientCredentialsOAuthFlow``
- ``ImplicitOAuthFlow``
- ``PasswordOAuthFlow``
- ``DeviceCodeOAuthFlow``

### データモデル — プッシュ通知

- ``TaskPushNotificationConfig``
- ``AuthenticationInfo``

### 操作

- ``SendMessageRequest``
- ``SendMessageConfiguration``
- ``SendMessageResponse``
- ``GetTaskRequest``
- ``CancelTaskRequest``
- ``SubscribeToTaskRequest``
- ``ListTasksRequest``
- ``ListTasksResponse``
- ``GetTaskPushNotificationConfigRequest``
- ``DeleteTaskPushNotificationConfigRequest``
- ``ListTaskPushNotificationConfigsRequest``
- ``ListTaskPushNotificationConfigsResponse``
- ``GetExtendedAgentCardRequest``

### ストリーミングイベント

- ``StreamResponse``
- ``TaskStatusUpdateEvent``
- ``TaskArtifactUpdateEvent``

### 識別子

- ``A2AIdentifier``

### JSON コーデックとメタデータ

- ``A2AJSON``
- ``A2AMetadata``
- ``ProtoEnum``
- ``RFC3339``

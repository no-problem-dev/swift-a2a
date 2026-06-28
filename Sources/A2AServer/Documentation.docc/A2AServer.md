# ``A2AServer``

A2A プロトコルのトランスポート非依存サーバフレームワーク — `AgentExecutor` を実装し `DefaultRequestHandler` へ渡すだけで、任意のトランスポートバインディングから公開できる。

## Overview

`A2AServer` は、ビジネスロジックを特定の HTTP ライブラリに結合せずに A2A 準拠エージェントをホストするために必要なものをすべて提供する。エージェントロジックは ``AgentExecutor`` に準拠した型に記述する。タスクライフサイクル・イベントファンアウト・プッシュ通知配信はフレームワークが処理するため、実装者は `StreamResponse` イベントを提供された ``EventQueue`` へ publish するだけでよい。

エグゼキュータをサーバへ組み込むには、エグゼキュータと適切なストア実装を持つ ``DefaultRequestHandler`` を生成する。そのハンドラを `A2AServerREST` の `RESTHandler`、`A2AServerJSONRPC` の `JSONRPCHandler` といったトランスポート層ディスパッチャへ渡すか、`A2AInProcess` の `A2AClient.inProcess(handler:)` でテストクライアントへ直結する。

```swift
import A2ACore
import A2AServer

struct EchoExecutor: AgentExecutor {
    func execute(_ context: RequestContext, eventQueue: EventQueue) async throws {
        let text = context.userInput()
        let status = TaskStatus(state: .completed, message: Message.agent("Echo: \(text)"))
        await eventQueue.enqueue(.statusUpdate(
            TaskStatusUpdateEvent(taskId: context.taskId, contextId: context.contextId, status: status)
        ))
        await eventQueue.close()
    }

    func cancel(_ context: RequestContext, eventQueue: EventQueue) async throws {
        let status = TaskStatus(state: .canceled)
        await eventQueue.enqueue(.statusUpdate(
            TaskStatusUpdateEvent(taskId: context.taskId, contextId: context.contextId, status: status)
        ))
        await eventQueue.close()
    }
}

let card = AgentCard(
    name: "Echo Agent",
    description: "入力をそのまま返すエージェント。",
    supportedInterfaces: [AgentInterface(url: "https://example.com/rpc", protocolBinding: "JSONRPC")],
    version: "1.0",
    capabilities: AgentCapabilities()
)
let handler = DefaultRequestHandler(agentCard: card, executor: EchoExecutor())
```

`A2AServer` はプロトタイピング向けのインメモリ実装を同梱する: ``InMemoryTaskStore``・``InMemoryQueueManager``・``InMemoryPushNotificationConfigStore``。本番環境では ``TaskStore``・``QueueManager``・``PushNotificationConfigStore`` に準拠した独自の永続化実装を用意する。

## Topics

### エージェント実行

- ``AgentExecutor``
- ``RequestContext``

### リクエスト処理

- ``RequestHandler``
- ``DefaultRequestHandler``
- ``ServerCallContext``
- ``ServerUser``

### タスク管理

- ``TaskManager``
- ``TaskStore``
- ``InMemoryTaskStore``
- ``TaskUpdater``
- ``ResultAggregator``
- ``OwnerResolver``

### イベントストリーミング

- ``EventQueue``
- ``QueueManager``
- ``InMemoryQueueManager``

### プッシュ通知

- ``PushNotificationConfigStore``
- ``InMemoryPushNotificationConfigStore``
- ``PushNotificationSender``
- ``HTTPPushNotificationSender``
- ``InProcessPushNotificationSender``

### エラー

- ``A2AServerError``

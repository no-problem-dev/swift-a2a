English | [日本語](README.md)

# swift-a2a

A Swift client for the [A2A (Agent2Agent) protocol](https://a2a-protocol.org/latest/) **v1.0**.

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![A2A](https://img.shields.io/badge/A2A-v1.0.1-green.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017+%20%7C%20macOS%2014+%20%7C%20tvOS%2017+%20%7C%20watchOS%2010+%20%7C%20visionOS%201+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## Features

- **Full A2A v1.0 conformance** — ProtoJSON serialization derived from the canonical Protocol Buffer definitions (`ROLE_USER`-style enums, camelCase fields, discriminator-less oneofs)
- **Two bindings** — **REST (HTTP+JSON)** and **JSON-RPC 2.0**, functionally equivalent (spec §5.1); pick whichever an agent supports
- **Layered by target** — use just the wire types via `A2ACore`, or the client via `A2AClientREST` / `A2AClientJSONRPC`. No umbrella; each layer carries only its own dependencies
- **SSE streaming** — real-time `message:stream` / `tasks:subscribe`
- **Type-safe, idiomatic Swift** — oneofs as enums, typed IDs, `@resultBuilder` message construction
- **Minimal dependencies** — Foundation + [swift-structured-data](https://github.com/no-problem-dev/swift-structured-data) only. No gRPC, no swift-syntax, no macros

## Architecture

| Product | Role | Depends on |
|---|---|---|
| `A2ACore` | Protocol layer: all wire types + ProtoJSON Codable + builders | StructuredDataCore |
| `A2AClientREST` | REST (HTTP+JSON) binding client | A2ACore |
| `A2AClientJSONRPC` | JSON-RPC 2.0 binding client | A2ACore |

Import only `A2ACore` when you just need the types (e.g. a server). Import the binding product you need for the client (or both, to negotiate via the Agent Card).

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-a2a.git", from: "0.3.0")
]
```

```swift
.target(name: "YourTarget", dependencies: [
    .product(name: "A2AClientREST", package: "swift-a2a"),      // for REST
    // .product(name: "A2AClientJSONRPC", package: "swift-a2a"), // for JSON-RPC
])
```

## Quick start

```swift
import A2ACore
import A2AClientREST   // or A2AClientJSONRPC

let client = A2AClient.rest(
    baseURL: URL(string: "https://agent.example.com/a2a/v1")!,
    authentication: .bearer("your-token")
)

// Discover the agent
let card = try await client.fetchAgentCard()   // /.well-known/agent-card.json

// Send a message
let response = try await client.sendMessage(.user("Create a sales report"))
switch response {
case .task(let task):    print(task.status.state)
case .message(let message): print(message.text)
}

// Build a multi-part message (string literals become text parts)
let message = Message(role: .user) {
    "Analyze this image"
    Part.file(uri: "https://example.com/photo.png", mediaType: "image/png")
    Part.data(["threshold": 0.8])
}

// Stream
for try await event in try await client.streamMessage(.user("Write a detailed report")) {
    switch event {
    case .task(let task): print(task.status.state)
    case .statusUpdate(let update): print(update.status.state)
    case .artifactUpdate(let update): print(update.artifact.parts.first?.text ?? "")
    case .message(let message): print(message.text)
    }
}

// Tasks
let task = try await client.getTask("task-id", historyLength: 10)
_ = try await client.cancelTask("task-id")
let list = try await client.listTasks(ListTasksRequest(status: .working))
```

## Error handling

```swift
do {
    _ = try await client.getTask("missing")
} catch let A2AError.rpc(error) {
    print(error.code)     // -32001
    print(error.reason)   // "TASK_NOT_FOUND" (from google.rpc.ErrorInfo)
}
```

## Supported operations

| Operation | Method | JSON-RPC | REST |
|---|---|---|---|
| Send message | `sendMessage` | `SendMessage` | `POST /message:send` |
| Streaming send | `streamMessage` | `SendStreamingMessage` | `POST /message:stream` |
| Get task | `getTask` | `GetTask` | `GET /tasks/{id}` |
| List tasks | `listTasks` | `ListTasks` | `GET /tasks` |
| Cancel task | `cancelTask` | `CancelTask` | `POST /tasks/{id}:cancel` |
| Subscribe to task | `subscribeToTask` | `SubscribeToTask` | `POST /tasks/{id}:subscribe` |
| Push config create/get/list/delete | `*PushNotificationConfig` | `*TaskPushNotificationConfig` | `/tasks/{id}/pushNotificationConfigs` |
| Extended Agent Card | `fetchExtendedAgentCard` | `GetExtendedAgentCard` | `GET /extendedAgentCard` |

## License

MIT

English | [日本語](README.md)

# swift-a2a

A Swift client implementation of the Google A2A (Agent-to-Agent) protocol

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017.0+%20%7C%20macOS%2014.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## Features

- **A2A Protocol Compliant** - Full implementation of the [Agent-to-Agent Protocol](https://a2a-protocol.org/) (JSON-RPC 2.0)
- **SSE Streaming** - Real-time task status and artifact updates via Server-Sent Events
- **Agent Card** - Auto-discovery of agent capabilities from `/.well-known/agent.json`
- **Flexible Authentication** - Bearer / API Key / Custom Headers / OAuth2 support
- **Swift Concurrency** - Actor-based design with full async/await + Sendable
- **Zero Dependencies** - Runs on Foundation only, no third-party dependencies

## Installation

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

## Quick Start

### Discover an Agent

```swift
import A2A

let client = A2AClient(configuration: .init(
    baseURL: URL(string: "https://agent.example.com")!,
    authentication: .bearer("your-token")
))

// Fetch Agent Card to inspect capabilities
let card = try await client.fetchAgentCard()
print(card.name)            // Agent name
print(card.skills)          // Available skills
print(card.capabilities)    // Streaming support, etc.
```

### Send a Message

```swift
// Send a text message
let task = try await client.sendMessage(
    Message(role: .user, parts: [.text(TextPart(text: "Generate a sales report"))])
)
print(task.status.state)    // .completed, .working, etc.

// Access generated artifacts
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

### Streaming

```swift
// Receive real-time updates via SSE streaming
let stream = try await client.streamMessage(
    Message(role: .user, parts: [.text(TextPart(text: "Generate a detailed report"))])
)

for try await event in stream {
    switch event {
    case .statusUpdate(let update):
        print("Status: \(update.status.state)")
    case .artifactUpdate(let update):
        print("Artifact: \(update.artifact.name ?? "")")
    }
}
```

### Task Management

```swift
// Check task status later by ID
let task = try await client.getTask(id: "task-123")

// Cancel a running task
let canceled = try await client.cancelTask(id: "task-123")
```

## API Overview

### Client Methods

| Method | Description |
|--------|-------------|
| `fetchAgentCard()` | Fetch Agent Card from `/.well-known/agent.json` |
| `sendMessage(_:configuration:)` | Send a message synchronously |
| `streamMessage(_:configuration:)` | Send a message with SSE streaming |
| `getTask(id:historyLength:)` | Retrieve task status by ID |
| `cancelTask(id:)` | Cancel a running task |

### Authentication

| Method | Use Case |
|--------|----------|
| `.bearer(String)` | Bearer token authentication |
| `.apiKey(headerName:value:)` | Custom header API key |
| `.headers([String: String])` | Arbitrary custom headers |
| `.none` | No authentication |

### Message Parts

| Part | Content |
|------|---------|
| `.text(TextPart)` | Text data |
| `.file(FilePart)` | File (binary or URI) |
| `.data(DataPart)` | Arbitrary structured data |

### Task States

`submitted` → `working` → `completed` / `failed` / `canceled` / `input-required` / `auth-required`

## About A2A

A2A (Agent-to-Agent) is an open protocol proposed by Google and hosted by the [Linux Foundation](https://www.linuxfoundation.org/). It enables interoperability between AI agents built with different frameworks and vendors.

- **MCP** handles agent ↔ tool/data connections (vertical integration)
- **A2A** handles agent ↔ agent collaboration (horizontal integration)

The two protocols are complementary — combining both lets you work with external tools and external agents through a unified interface.

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.2+
- Xcode 16.0+

## License

MIT License - See [LICENSE](LICENSE) for details

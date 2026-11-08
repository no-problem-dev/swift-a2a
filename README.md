# swift-a2a

English | [日本語](./README.ja.md)

A Swift implementation of the [A2A (Agent2Agent) protocol](https://a2a-protocol.org/latest/) — client, server, and an in-process binding for testing.

> **Unofficial.** Not affiliated with or endorsed by the authors of the A2A protocol. Conforming to the specification is not a goal of this project.

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![A2A](https://img.shields.io/badge/A2A-v1.0.1-green.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017+%20%7C%20macOS%2014+%20%7C%20tvOS%2017+%20%7C%20watchOS%2010+%20%7C%20visionOS%201+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## Features

- **Two bindings, one API** — REST (HTTP+JSON, spec §11) and JSON-RPC 2.0 (§9), which the spec requires to be functionally equivalent. Pick whichever an agent's card advertises; nothing else changes
- **ProtoJSON-shaped wire format** — `ROLE_USER`-style enum names, camelCase fields, discriminator-less oneofs, RFC 3339 timestamps. Where a type departs from the Protocol Buffer definition on purpose, that type's own documentation says so
- **Write a server by writing one type** — conform to `AgentExecutor`, hand it to `DefaultRequestHandler`, serve it through a transport-agnostic dispatcher
- **Test without a network** — `A2AClient.inProcess(handler:)` connects a client straight to a handler, no HTTP and no serialization
- **SSE streaming** — `message:stream` and `tasks:subscribe`, with a parser that does not lose event boundaries
- **Type-safe and idiomatic** — oneofs as enums, typed identifiers, `@resultBuilder` message construction
- **Two dependencies** — Foundation and [swift-structured-data](https://github.com/no-problem-dev/swift-structured-data). No gRPC, no swift-syntax, no macros

## Quick Start

```swift
import A2AClientREST   // or A2AClientJSONRPC

let client = A2AClient.rest(
    baseURL: URL(string: "https://agent.example.com/a2a/v1")!,
    authentication: .bearer("your-token")
)

let response = try await client.sendMessage(.user("Create a sales report"))

switch response {
case .task(let task):
    print(task.status.state)
    print(task.artifacts.first?.parts.first?.text ?? "")
case .message(let message):
    print(message.text)
}
```

Streaming, task operations, push notification configuration, and the server side are covered in the documentation.

## Documentation

Each library has its own DocC page:

- [A2ACore](Sources/A2ACore/Documentation.docc) — the data model and its encoding
- [A2AClientREST](Sources/A2AClientREST/Documentation.docc) · [A2AClientJSONRPC](Sources/A2AClientJSONRPC/Documentation.docc) — the two client bindings
- [A2AServer](Sources/A2AServer/Documentation.docc) — writing and hosting an agent
- [A2AServerREST](Sources/A2AServerREST/Documentation.docc) · [A2AServerJSONRPC](Sources/A2AServerJSONRPC/Documentation.docc) — the server-side dispatchers
- [A2AInProcess](Sources/A2AInProcess/Documentation.docc) — testing without a network

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-a2a.git", .upToNextMinor(from: "0.8.0"))
]
```

Then add the products you need — the client binding for talking to an agent, the server ones for hosting:

```swift
.target(name: "YourTarget", dependencies: [
    .product(name: "A2AClientREST", package: "swift-a2a"),
    // .product(name: "A2AClientJSONRPC", package: "swift-a2a"),
])
```

## Requirements

| swift-a2a | Swift | Platforms |
|---|---|---|
| 0.x | 6.2+ | iOS 17+ · macOS 14+ · tvOS 17+ · watchOS 10+ · visionOS 1+ · Linux |

Targets A2A revision 1.0.1. The gRPC binding is not implemented.

## License

MIT. See [LICENSE](LICENSE).

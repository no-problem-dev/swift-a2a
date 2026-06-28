# ``A2AInProcess``

In-process A2A binding — connects an `A2AClient` directly to a `RequestHandler` in the same process, bypassing all HTTP and serialization overhead.

## Overview

`A2AInProcess` is designed for testing and for embedding an agent within the same binary that consumes it. Importing this module re-exports `A2ACore`, `A2AClientCore`, and `A2AServer`, so a single import gives you access to the full stack.

Call the `A2AClient.inProcess(handler:context:)` factory to create a client backed by an ``InProcessTransport``. The transport forwards each operation directly to the `RequestHandler` without serializing to JSON or opening a network socket. This makes round-trip latency negligible and keeps test output deterministic.

```swift
import A2ACore
import A2AServer
import A2AInProcess

// Build a handler using the server framework
let card = AgentCard(
    name: "Echo Agent",
    description: "Echoes input.",
    supportedInterfaces: [AgentInterface(url: "inprocess://local", protocolBinding: "JSONRPC")],
    version: "1.0",
    capabilities: AgentCapabilities()
)
let handler = DefaultRequestHandler(agentCard: card, executor: EchoExecutor())

// Wire a client directly to the handler — no HTTP involved
let client = A2AClient.inProcess(handler: handler)

let response = try await client.sendMessage(Message.user("Hello!"))
if case .task(let task) = response {
    print("Task state:", task.status.state)
}
```

You can also pass a custom `ServerCallContext` to `inProcess(handler:context:)` if you need to inject authentication information or other per-call metadata during tests.

## Topics

### Transport

- ``InProcessTransport``

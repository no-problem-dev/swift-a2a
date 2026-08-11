# ``A2AInProcess``

Wires a client straight to a handler in the same process — no HTTP, no serialization.

## Overview

`A2AInProcess` is for testing an agent, and for embedding one in the binary that calls it. The
client protocol is implemented by calling a `RequestHandler` directly, so values pass as Swift
types and round-trip latency disappears.

Importing this module re-exports `A2ACore`, `A2AClientCore` and `A2AServer`, so one import brings
the whole stack.

```swift
import A2AInProcess

let card = AgentCard(
    name: "Echo Agent",
    description: "Returns whatever it is sent.",
    supportedInterfaces: [AgentInterface(url: "inprocess://local", protocolBinding: "JSONRPC")],
    version: "1.0",
    capabilities: AgentCapabilities()
)
let handler = DefaultRequestHandler(agentCard: card, executor: EchoExecutor())

let client = A2AClient.inProcess(handler: handler)

let response = try await client.sendMessage(Message.user("Hello!"))
if case .task(let task) = response {
    print("Task state:", task.status.state)
}
```

Pass a `ServerCallContext` to `inProcess(handler:context:)` to run as an authenticated caller. It is
fixed for the life of the client, so testing two identities means two clients.

### What this transport does not exercise

Speed comes from skipping work, and the skipped work is exactly what a remote binding would test.
Nothing is encoded, so a payload that would fail to serialize passes unnoticed; there is no HTTP
layer, so `fetchAgentCard()` — which always goes over the network — cannot be used on such a
client. Error handling also differs: `A2AServerError` is translated to `A2AError.rpc` as a remote
binding would, but any other error the handler throws propagates unchanged rather than becoming a
generic internal error.

Treat a passing in-process test as evidence about the agent, not about the wire format.

## Topics

### Transport

- ``InProcessTransport``

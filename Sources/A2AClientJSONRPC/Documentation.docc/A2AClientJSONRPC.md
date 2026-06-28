# ``A2AClientJSONRPC``

JSON-RPC 2.0 binding for the A2A client — adds the `A2AClient.jsonRPC(endpoint:)` factory and the underlying `JSONRPCTransport`.

## Overview

`A2AClientJSONRPC` provides the JSON-RPC binding described in section 9 of the A2A specification. Like its REST sibling `A2AClientREST`, importing this module re-exports the full `A2AClient` façade and the `A2ACore` data model, so no additional imports are needed.

Create a client by calling the `A2AClient.jsonRPC(endpoint:authentication:)` factory. This wires a ``JSONRPCTransport`` — which POSTs all requests to a single endpoint URL with method names such as `SendMessage`, `GetTask`, and `SubscribeToTask` — to the shared `A2AClient` façade.

```swift
import A2AClientJSONRPC

let client = A2AClient.jsonRPC(
    endpoint: URL(string: "https://agent.example.com/rpc")!,
    authentication: .bearer("my-token")
)

// Retrieve a known task by ID
let task = try await client.getTask(TaskID("abc-123"))
print("State:", task.status.state)

// Subscribe to updates for a running task
let updates = try await client.subscribeToTask(TaskID("abc-123"))
for try await event in updates {
    print(event)
}
```

``JSONRPCTransport`` is publicly accessible for cases where you want to compose it with a custom `HTTPClient`.

## Topics

### Transport

- ``JSONRPCTransport``

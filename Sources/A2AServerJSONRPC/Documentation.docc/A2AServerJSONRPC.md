# ``A2AServerJSONRPC``

JSON-RPC 2.0 server-side dispatcher for the A2A protocol — decodes JSON-RPC envelopes, dispatches to a `RequestHandler`, and encodes responses back to raw bytes.

## Overview

`A2AServerJSONRPC` is the thin protocol-translation layer that sits between your HTTP server and the transport-independent `A2AServer` framework. It is intentionally HTTP-library-agnostic: it receives a `Data` blob and returns a ``JSONRPCOutcome``, which is either a single ``JSONRPCOutcome/unary(_:)`` `Data` value or a ``JSONRPCOutcome/stream(_:)`` of `Data` values (one per SSE frame). Your HTTP framework is responsible for writing those bytes to the response body.

Create a ``JSONRPCHandler`` with any `RequestHandler` and call ``JSONRPCHandler/handle(_:context:)`` for each incoming request. The handler routes by the `method` field (for example `SendMessage`, `GetTask`, `SubscribeToTask`) to the matching `RequestHandler` method, wraps the result in a standard `{jsonrpc: "2.0", id, result}` envelope, and returns the encoded bytes:

```swift
import A2ACore
import A2AServer
import A2AServerJSONRPC

// Compose with any RequestHandler from A2AServer
let handler = DefaultRequestHandler(agentCard: card, executor: myExecutor)
let rpcHandler = JSONRPCHandler(handler: handler)

// In your HTTP route handler (pseudo-code):
let requestData: Data = httpRequest.body
let outcome = await rpcHandler.handle(requestData)

switch outcome {
case .unary(let data):
    httpResponse.write(data)
case .stream(let events):
    for try await chunk in events {
        httpResponse.writeSSEFrame(chunk)
    }
}
```

## Topics

### Dispatching

- ``JSONRPCHandler``
- ``JSONRPCOutcome``

# ``A2AServerJSONRPC``

Turns JSON-RPC request bytes into handler calls, and answers into response bytes.

## Overview

`A2AServerJSONRPC` sits between an HTTP server and the transport-agnostic `A2AServer` framework. It
takes `Data` and returns a ``JSONRPCOutcome``: either one encoded envelope, or a stream of them,
one per event. Framing those bytes — writing a body, or wrapping each element in an SSE frame — is
the HTTP layer's job, which is what keeps this module free of any HTTP dependency.

```swift
import A2AServer
import A2AServerJSONRPC

let rpcHandler = JSONRPCHandler(handler: DefaultRequestHandler(agentCard: card, executor: myExecutor))

// Inside your HTTP route (pseudocode):
let outcome = await rpcHandler.handle(httpRequest.body, context: contextFrom(httpRequest))

switch outcome {
case .unary(let data):
    httpResponse.write(data)
case .stream(let events):
    for try await chunk in events {
        httpResponse.writeSSEFrame(chunk)
    }
}
```

### Two things the HTTP layer owns

**Authentication.** ``JSONRPCHandler/handle(_:context:)`` defaults its context to an
unauthenticated caller. Nothing in this module inspects headers, so unless you build a
`ServerCallContext` and pass it, every request shares one storage scope and callers can read each
other's tasks.

**The status code.** Dispatching never throws — a parse failure, an unknown method, bad params and
an error from the handler all come back as an error envelope. JSON-RPC carries the failure in the
body, so the HTTP status is yours to choose; `200` for everything the dispatcher produces is the
conventional answer.

An error raised after a stream has already opened is yielded as an error envelope on that stream,
which then finishes normally rather than throwing.

## Topics

### Dispatching

- ``JSONRPCHandler``
- ``JSONRPCOutcome``

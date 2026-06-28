# ``A2AServerREST``

REST server-side dispatcher for the A2A protocol — routes HTTP method and path to a `RequestHandler` and returns typed request/response values that your HTTP framework writes to the wire.

## Overview

`A2AServerREST` is the transport-translation layer for the HTTP+JSON REST binding described in section 11 of the A2A specification. Like `A2AServerJSONRPC`, it is HTTP-library-agnostic: it accepts a ``RESTRequest`` (HTTP method, path, query parameters, and raw body bytes) and returns a ``RESTOutcome`` that is either a single ``RESTOutcome/response(_:)`` or a ``RESTOutcome/stream(_:)`` of raw event `Data` values for SSE.

Create a ``RESTHandler`` with any `RequestHandler` from `A2AServer`. The handler matches paths such as `POST /message:send`, `GET /tasks/{id}`, `POST /tasks/{id}:cancel`, and `GET /extendedAgentCard`, delegates to the corresponding `RequestHandler` method, then encodes the result back to JSON bytes:

```swift
import A2ACore
import A2AServer
import A2AServerREST

let handler = DefaultRequestHandler(agentCard: card, executor: myExecutor)
let restHandler = RESTHandler(handler: handler)

// In your HTTP route handler (pseudo-code):
let request = RESTRequest(
    method: "POST",
    path: "/message:send",
    query: [:],
    body: httpRequest.body
)
let outcome = await restHandler.handle(request)

switch outcome {
case .response(let resp):
    httpResponse.status = resp.status
    httpResponse.write(resp.body)
case .stream(let events):
    for try await chunk in events {
        httpResponse.writeSSEFrame(chunk)
    }
}
```

## Topics

### Dispatching

- ``RESTHandler``
- ``RESTRequest``
- ``RESTResponse``
- ``RESTOutcome``

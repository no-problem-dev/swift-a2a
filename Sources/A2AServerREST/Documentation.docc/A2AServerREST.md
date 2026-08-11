# ``A2AServerREST``

Routes an HTTP method and path to a handler call, and returns what to write back.

## Overview

`A2AServerREST` implements the resource mapping of A2A spec §11 as a pure function over
``RESTRequest``. It returns a ``RESTOutcome``: either a complete ``RESTResponse``, or a stream of
encoded events. No HTTP types cross the boundary, which is what lets it drop into any server.

```swift
import A2AServer
import A2AServerREST

let restHandler = RESTHandler(handler: DefaultRequestHandler(agentCard: card, executor: myExecutor))

// Inside your HTTP route (pseudocode):
let request = RESTRequest(
    method: httpRequest.method,
    path: httpRequest.path,
    query: httpRequest.queryParameters,
    body: httpRequest.body
)
let outcome = await restHandler.handle(request, context: contextFrom(httpRequest))

switch outcome {
case .response(let response):
    httpResponse.status = response.status
    httpResponse.contentType = response.contentType
    httpResponse.write(response.body)
case .stream(let events):
    httpResponse.contentType = "text/event-stream"
    for try await chunk in events {
        httpResponse.writeSSEFrame(chunk)
    }
}
```

Custom verbs are the `:verb` suffix on a path segment — `POST /tasks/{id}:cancel`,
`POST /tasks/{id}:subscribe` — and identifiers in the path are percent-decoded before use.

### What the HTTP layer owns

**Authentication.** ``RESTHandler/handle(_:context:)`` defaults its context to an unauthenticated
caller. Build a `ServerCallContext` from the request and pass it, or every caller shares one storage
scope.

**The stream's content type.** The stream case carries no `RESTResponse`, so nothing tells you it is
Server-Sent Events. Set `text/event-stream` yourself.

Dispatching never throws: every failure becomes an error response whose status comes from the A2A
code. Note that a path matching no route answers `404` carrying the task-not-found code, whether or
not the request concerned a task.

## Topics

### Dispatching

- ``RESTHandler``
- ``RESTRequest``
- ``RESTResponse``
- ``RESTOutcome``

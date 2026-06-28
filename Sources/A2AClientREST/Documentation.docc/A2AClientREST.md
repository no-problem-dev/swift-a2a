# ``A2AClientREST``

HTTP+JSON REST binding for the A2A client — adds the `A2AClient.rest(baseURL:)` factory and the underlying `RESTTransport`.

## Overview

`A2AClientREST` provides the REST binding described in section 11 of the A2A specification. Importing this module gives you access to the full `A2AClient` façade (re-exported from `A2AClientCore`) together with the `A2ACore` data model, so a single import is all you need to start making requests.

Create a client by calling the `A2AClient.rest(baseURL:authentication:)` factory. Under the hood, this wires a ``RESTTransport`` to the shared `A2AClient` façade. The transport maps each A2A operation to a distinct HTTP path (`/message:send`, `/tasks/{id}`, `/tasks/{id}:cancel`, etc.) and handles Server-Sent Events for streaming responses.

```swift
import A2AClientREST

let client = A2AClient.rest(
    baseURL: URL(string: "https://agent.example.com")!,
    authentication: .bearer("my-token")
)

// Non-streaming: returns a task or an immediate message reply
let response = try await client.sendMessage(Message.user("Hello!"))

// Streaming: yields TaskStatusUpdateEvent and TaskArtifactUpdateEvent values
let stream = try await client.streamMessage(Message.user("Process this in the background."))
for try await event in stream {
    print(event)
}
```

``RESTTransport`` is exposed as a public type so you can compose it with your own `HTTPClient` if you need to customise connection behaviour or add middleware beyond what `A2AAuthentication` covers.

## Topics

### Transport

- ``RESTTransport``

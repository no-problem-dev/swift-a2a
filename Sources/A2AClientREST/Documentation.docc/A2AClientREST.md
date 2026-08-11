# ``A2AClientREST``

The HTTP+JSON binding: `A2AClient.rest(baseURL:)` and the transport behind it.

## Overview

`A2AClientREST` implements the REST binding of A2A spec §11 — resource paths and standard verbs,
with no envelope. Each operation is its own path (`/message:send`, `/tasks/{id}`,
`/tasks/{id}:cancel`), and streaming operations answer with Server-Sent Events whose data is the
event itself.

Importing this module is enough: it re-exports `A2ACore` and the client facade, so nothing else has
to be imported to build and send a message.

```swift
import A2AClientREST

let client = A2AClient.rest(
    baseURL: URL(string: "https://agent.example.com")!,
    authentication: .bearer("my-token")
)

// Waits for the outcome: a task to follow, or a direct reply.
let response = try await client.sendMessage(Message.user("Hello!"))

// Or take the updates as they happen. The stream ends when the task settles.
let stream = try await client.streamMessage(Message.user("Process this in the background."))
for try await event in stream {
    print(event)
}
```

Which binding an agent speaks is its choice, not yours: read `supportedInterfaces` on its card and
build the matching client. The specification requires the bindings to be functionally equivalent
(§5.1), so the code around the client does not change either way.

### Errors

A non-2xx response whose body is a `google.rpc.Status` becomes `A2AError.rpc`, carrying the code
and any `reason` in the details. When the body cannot be read that way, only the status is known
and it becomes `A2AError.http`. Branch on `reason` or `code` — never on the message.

``RESTTransport`` is public, so it can be paired with a `HTTPClient` you configured yourself when
the factory's parameters are not enough.

## Topics

### Transport

- ``RESTTransport``

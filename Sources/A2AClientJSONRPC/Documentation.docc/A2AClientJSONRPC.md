# ``A2AClientJSONRPC``

The JSON-RPC 2.0 binding: `A2AClient.jsonRPC(endpoint:)` and the transport behind it.

## Overview

`A2AClientJSONRPC` implements the JSON-RPC binding of A2A spec §9. Every operation is a POST to one
endpoint, distinguished by the method name in the envelope — `SendMessage`, `GetTask`,
`SubscribeToTask` — and streaming operations answer with Server-Sent Events whose data is one
response envelope per event.

Importing this module is enough: it re-exports `A2ACore` and the client facade, so nothing else has
to be imported to build and send a message.

```swift
import A2AClientJSONRPC

let client = A2AClient.jsonRPC(
    endpoint: URL(string: "https://agent.example.com/rpc")!,
    authentication: .bearer("my-token")
)

let task = try await client.getTask(TaskID("abc-123"))
print("State:", task.status.state)

// The first event is always a snapshot of the task as it stands.
for try await event in try await client.subscribeToTask(TaskID("abc-123")) {
    print(event)
}
```

The agent card decides which binding to use: read `supportedInterfaces` and build the matching
client. The specification requires the bindings to be functionally equivalent (§5.1), so nothing
around the client changes with the choice.

### Errors

An error object inside a response envelope becomes `A2AError.rpc`, keeping its code and any
`reason` in the details. A non-2xx response whose body is not an envelope becomes `A2AError.http`,
where only the status is known.

Request ids are fresh UUIDs and responses are not matched against them, so this transport cannot be
used for batched or out-of-order JSON-RPC.

``JSONRPCTransport`` is public, so it can be paired with a `HTTPClient` you configured yourself when
the factory's parameters are not enough.

## Topics

### Transport

- ``JSONRPCTransport``

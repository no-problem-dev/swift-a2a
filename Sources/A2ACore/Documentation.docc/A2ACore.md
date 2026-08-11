# ``A2ACore``

The A2A data model and its ProtoJSON encoding, shared by every other module in the package.

> **Unofficial.** Not affiliated with or endorsed by the authors of the A2A protocol. Conforming to the specification is not a goal of this project.

## Overview

swift-a2a targets the Agent2Agent protocol, revision 1.0.1. It is split into seven libraries so
you take only the layer you need, and ``A2ACore`` is what they all rest on: the task, message,
part, artifact and agent-card types, every operation's request and response, the streaming event
types, and the coders that write them the way the specification requires.

Nothing in this module talks to a network. It is the vocabulary; the bindings move it.

On the client side, `A2AClientREST` and `A2AClientJSONRPC` each pair the shared `A2AClient` facade
with one transport — the HTTP+JSON binding of spec §11, and the JSON-RPC 2.0 binding of §9. The
specification requires the two to be functionally equivalent, so the choice is the agent's, not
yours. Both modules re-export ``A2ACore``, so one import is enough to build and send a message.

On the server side, `A2AServer` is transport-agnostic: implement `AgentExecutor`, hand it to
`DefaultRequestHandler`, and let `A2AServerREST` or `A2AServerJSONRPC` translate bytes into handler
calls. `A2AInProcess` connects a client straight to a handler with no serialization at all, which
is how you test an agent without standing up a server.

```swift
import A2ACore
import A2AClientREST

let client = A2AClient.rest(baseURL: URL(string: "https://agent.example.com")!)

let message = Message.user("Summarize the attached document.")
let response = try await client.sendMessage(message)

switch response {
case .task(let task):
    print("Task", task.id.rawValue, "is", task.status.state)
case .message(let reply):
    print("Replied:", reply.text)
}
```

### Reading the wire format

Two conventions explain most of what the encoding does, and both come from Protocol Buffers rather
than from anything Swift would suggest.

Enums travel as their Protocol Buffer names — `ROLE_USER`, `TASK_STATE_WORKING` — and an
unrecognized name decodes to `unspecified` rather than failing, so a client keeps working against
an agent that has learned a new state. See ``ProtoEnum`` for the one place that tolerance costs
something.

Fields equal to their proto3 default are omitted on the way out and defaulted on the way in, so an
absent field and an empty one are the same thing. This is why decoding a required-looking field
that is missing yields an empty value instead of an error.

Where this implementation departs from the canonical definitions on purpose, the type says so:
``SecurityRequirement`` and ``OAuthFlows`` both follow the specification's examples and the
ecosystem rather than the proto shape.

## Topics

### Protocol Constants

- ``A2AProtocol``

### Tasks

- ``A2ATask``
- ``TaskStatus``
- ``TaskState``
- ``TaskID``
- ``ContextID``

### Messages and Parts

- ``Message``
- ``Part``
- ``PartBuilder``
- ``Role``
- ``MessageID``

### Artifacts

- ``Artifact``
- ``ArtifactID``

### Agent Cards

- ``AgentCard``
- ``AgentSkill``
- ``AgentCapabilities``
- ``AgentProvider``
- ``AgentInterface``
- ``AgentExtension``
- ``AgentCardSignature``

### Security Schemes

- ``SecurityScheme``
- ``SecurityRequirement``
- ``APIKeySecurityScheme``
- ``HTTPAuthSecurityScheme``
- ``OAuth2SecurityScheme``
- ``OpenIdConnectSecurityScheme``
- ``MutualTLSSecurityScheme``
- ``OAuthFlows``
- ``AuthorizationCodeOAuthFlow``
- ``ClientCredentialsOAuthFlow``
- ``ImplicitOAuthFlow``
- ``PasswordOAuthFlow``
- ``DeviceCodeOAuthFlow``

### Push Notifications

- ``TaskPushNotificationConfig``
- ``AuthenticationInfo``

### Operations

- ``SendMessageRequest``
- ``SendMessageConfiguration``
- ``SendMessageResponse``
- ``GetTaskRequest``
- ``CancelTaskRequest``
- ``SubscribeToTaskRequest``
- ``ListTasksRequest``
- ``ListTasksResponse``
- ``GetTaskPushNotificationConfigRequest``
- ``DeleteTaskPushNotificationConfigRequest``
- ``ListTaskPushNotificationConfigsRequest``
- ``ListTaskPushNotificationConfigsResponse``
- ``GetExtendedAgentCardRequest``

### Streaming Events

- ``StreamResponse``
- ``TaskStatusUpdateEvent``
- ``TaskArtifactUpdateEvent``

### Identifiers

- ``A2AIdentifier``

### Encoding

- ``A2AJSON``
- ``A2AMetadata``
- ``ProtoEnum``
- ``RFC3339``

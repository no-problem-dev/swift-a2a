# ``A2ACore``

Swift implementation of the Agent-to-Agent (A2A) protocol — shared data model, operation types, and protocol constants used by every module in the swift-a2a package.

## Overview

swift-a2a is a modular Swift implementation of Google's Agent-to-Agent (A2A) protocol (v1.0.1). The package is split into seven libraries so you can adopt only the layers you need. ``A2ACore`` is the shared foundation: it defines the complete A2A data model — tasks, messages, parts, artifacts, and agent cards — together with the full set of operation request and response types, stream-event types, and the JSON codec. Every other library in this package depends on ``A2ACore``.

The client-side libraries `A2AClientREST` and `A2AClientJSONRPC` each wrap the shared `A2AClient` façade with a concrete transport binding. `A2AClientREST` uses the HTTP+JSON REST binding (spec §11) while `A2AClientJSONRPC` uses the JSON-RPC 2.0 binding (spec §9). Both modules re-export ``A2ACore``, so a single import statement gives you everything needed to build and send messages.

The server-side is handled by three complementary libraries. `A2AServer` provides the transport-independent framework: the `AgentExecutor` and `RequestHandler` protocols, the `TaskManager` actor for lifecycle management, and in-memory store implementations for quick prototyping. `A2AServerREST` and `A2AServerJSONRPC` add thin HTTP-independent dispatchers that translate raw bytes into `RequestHandler` calls. Finally, `A2AInProcess` connects an `A2AClient` directly to a `RequestHandler` in the same process without any networking, which makes it easy to write unit tests against a real agent implementation.

The following example creates a text message using ``Message/user(_:messageId:)`` and inspects the result returned by a remote agent via the REST client:

```swift
import A2ACore
import A2AClientREST

let client = A2AClient.rest(baseURL: URL(string: "https://agent.example.com")!)

let message = Message.user("Summarise the attached document.")
let response = try await client.sendMessage(message)

switch response {
case .task(let task):
    print("Task created:", task.id.rawValue, "state:", task.status.state)
case .message(let reply):
    print("Immediate reply:", reply.text)
}
```

## Topics

### Protocol Constants

- ``A2AProtocol``

### Data Model — Tasks

- ``A2ATask``
- ``TaskStatus``
- ``TaskState``
- ``TaskID``
- ``ContextID``

### Data Model — Messages & Parts

- ``Message``
- ``Part``
- ``PartBuilder``
- ``Role``
- ``MessageID``

### Data Model — Artifacts

- ``Artifact``
- ``ArtifactID``

### Data Model — Agent Card

- ``AgentCard``
- ``AgentSkill``
- ``AgentCapabilities``
- ``AgentProvider``
- ``AgentInterface``
- ``AgentExtension``
- ``AgentCardSignature``

### Data Model — Security Schemes

- ``SecurityScheme``
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

### Data Model — Push Notifications

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

### JSON Codec & Metadata

- ``A2AJSON``
- ``A2AMetadata``
- ``ProtoEnum``
- ``RFC3339``

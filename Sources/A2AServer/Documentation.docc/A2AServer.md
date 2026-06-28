# ``A2AServer``

Transport-independent server framework for the A2A protocol — implement `AgentExecutor`, wire it to `DefaultRequestHandler`, and expose it through any transport binding.

## Overview

`A2AServer` provides everything you need to host an A2A-compliant agent without coupling your business logic to a particular HTTP library. Your agent logic goes into a type that conforms to ``AgentExecutor``. The framework takes care of task lifecycle, event fan-out, and push-notification delivery; you only need to publish `StreamResponse` events to the provided ``EventQueue``.

To wire an executor into a server, create a ``DefaultRequestHandler`` with the executor and appropriate store implementations. You then pass the handler to a transport-layer dispatcher such as `RESTHandler` (from `A2AServerREST`) or `JSONRPCHandler` (from `A2AServerJSONRPC`), or connect directly to a test client via `A2AClient.inProcess(handler:)` from `A2AInProcess`.

```swift
import A2ACore
import A2AServer

struct EchoExecutor: AgentExecutor {
    func execute(_ context: RequestContext, eventQueue: EventQueue) async throws {
        let text = context.userInput()
        let status = TaskStatus(state: .completed, message: Message.agent("Echo: \(text)"))
        await eventQueue.enqueue(.statusUpdate(
            TaskStatusUpdateEvent(taskId: context.taskId, contextId: context.contextId, status: status)
        ))
        await eventQueue.close()
    }

    func cancel(_ context: RequestContext, eventQueue: EventQueue) async throws {
        let status = TaskStatus(state: .canceled)
        await eventQueue.enqueue(.statusUpdate(
            TaskStatusUpdateEvent(taskId: context.taskId, contextId: context.contextId, status: status)
        ))
        await eventQueue.close()
    }
}

let card = AgentCard(
    name: "Echo Agent",
    description: "Echoes input back as a reply.",
    supportedInterfaces: [AgentInterface(url: "https://example.com/rpc", protocolBinding: "JSONRPC")],
    version: "1.0",
    capabilities: AgentCapabilities()
)
let handler = DefaultRequestHandler(agentCard: card, executor: EchoExecutor())
```

`A2AServer` ships in-memory implementations for quick prototyping: ``InMemoryTaskStore``, ``InMemoryQueueManager``, and ``InMemoryPushNotificationConfigStore``. For production use, conform to ``TaskStore``, ``QueueManager``, and ``PushNotificationConfigStore`` and supply your own persistence-backed implementations.

## Topics

### Agent Execution

- ``AgentExecutor``
- ``RequestContext``

### Request Handling

- ``RequestHandler``
- ``DefaultRequestHandler``
- ``ServerCallContext``
- ``ServerUser``

### Task Management

- ``TaskManager``
- ``TaskStore``
- ``InMemoryTaskStore``
- ``TaskUpdater``
- ``ResultAggregator``
- ``OwnerResolver``

### Event Streaming

- ``EventQueue``
- ``QueueManager``
- ``InMemoryQueueManager``

### Push Notifications

- ``PushNotificationConfigStore``
- ``InMemoryPushNotificationConfigStore``
- ``PushNotificationSender``
- ``HTTPPushNotificationSender``
- ``InProcessPushNotificationSender``

### Errors

- ``A2AServerError``

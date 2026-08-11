# ``A2AServer``

Host an A2A agent by writing one type: an executor. Everything else is here.

## Overview

`A2AServer` holds the machinery an agent needs and none of the HTTP. Write the agent's logic as an
``AgentExecutor``, hand it to a ``DefaultRequestHandler``, and pass that handler to whichever
transport dispatcher you serve — `RESTHandler`, `JSONRPCHandler`, or `A2AClient.inProcess(handler:)`
in tests.

The executor publishes events; the framework persists the task, fans events out to subscribers,
delivers push notifications, and decides what a client gets back.

```swift
import A2ACore
import A2AServer

struct EchoExecutor: AgentExecutor {
    func execute(_ context: RequestContext, eventQueue: EventQueue) async throws {
        let updater = TaskUpdater(
            eventQueue: eventQueue,
            taskId: context.taskId,
            contextId: context.contextId
        )
        try await updater.startWork()
        let reply = await updater.makeAgentMessage([.text("Echo: \(context.userInput())")])
        try await updater.complete(message: reply)
    }

    func cancel(_ context: RequestContext, eventQueue: EventQueue) async throws {
        let updater = TaskUpdater(
            eventQueue: eventQueue,
            taskId: context.taskId,
            contextId: context.contextId
        )
        try await updater.cancel()
    }
}

let card = AgentCard(
    name: "Echo Agent",
    description: "Returns whatever it is sent.",
    supportedInterfaces: [AgentInterface(url: "https://example.com/rpc", protocolBinding: "JSONRPC")],
    version: "1.0",
    capabilities: AgentCapabilities(streaming: true)
)
let handler = DefaultRequestHandler(agentCard: card, executor: EchoExecutor())
```

### What an executor must guarantee

Return only after publishing a terminal state — completed, failed, canceled or rejected — or an
interrupted one. Returning early leaves a blocking send waiting on a task that never settles.

Publishing `.inputRequired` ends the run, and the framework calls `execute` again with the same task
once the client answers. An executor must therefore be able to resume from
``RequestContext/currentTask`` rather than assuming it starts from nothing.

Throwing is a legitimate failure path: the framework publishes a failed status for you. Cancellation
is not a failure — a cancelled run ends quietly.

### Capabilities are enforced

The agent card is not decoration. Streaming requests are refused unless `capabilities.streaming` is
explicitly `true`, and the extended card is refused unless `capabilities.extendedAgentCard` is
explicitly `true`. An absent flag counts as unsupported.

### Cancellation is the executor's decision

`onCancelTask` interrupts the running executor and then calls its `cancel`. The request only
succeeds if that leaves the task in the canceled state; an executor that declines makes the
request fail as not cancelable, which is exactly what the protocol intends.

### Storage is scoped by caller

Every store method takes a ``ServerCallContext`` and partitions by the owner an ``OwnerResolver``
derives from it, so one caller cannot read another's tasks. The transport dispatchers do not
populate that context — they default it — so authentication belongs in the HTTP layer that builds a
context before handing bytes to a dispatcher. Leaving it at its default puts every caller in one
shared scope, which is right only for a single-tenant agent.

### The in-memory stores are for prototyping

``InMemoryTaskStore``, ``InMemoryQueueManager`` and ``InMemoryPushNotificationConfigStore`` keep
everything in process memory. Nothing survives a restart, and nothing is visible to a second
instance — which also means a subscription can only be served by the process that started the run.
Implement ``TaskStore``, ``QueueManager`` and ``PushNotificationConfigStore`` over shared storage
before running more than one.

## Topics

### Writing an Agent

- ``AgentExecutor``
- ``RequestContext``
- ``TaskUpdater``

### Serving Requests

- ``RequestHandler``
- ``DefaultRequestHandler``
- ``ServerCallContext``
- ``ServerUser``
- ``A2AServerError``

### Storing Tasks

- ``TaskStore``
- ``InMemoryTaskStore``
- ``TaskManager``
- ``ResultAggregator``
- ``OwnerResolver``

### Streaming Events

- ``EventQueue``
- ``QueueManager``
- ``InMemoryQueueManager``

### Push Notifications

- ``PushNotificationConfigStore``
- ``InMemoryPushNotificationConfigStore``
- ``PushNotificationSender``
- ``HTTPPushNotificationSender``
- ``InProcessPushNotificationSender``

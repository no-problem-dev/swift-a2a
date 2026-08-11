import Foundation
import Testing
@testable import A2ACore

/// Ports the cases from the reference implementation's proto-utils tests that have a counterpart
/// in the Codable layer here — the four stream-response variants.
///
/// The rest do not port. Two are Python-side protobuf helpers with no equivalent, and required-field
/// validation is a server-side check this client deliberately does not perform: proto3 decoding here
/// defaults missing fields rather than rejecting them.
@Suite("Official proto_utils parity (StreamResponse)")
struct OfficialProtoUtilsTests {
    let decoder = A2AJSON.makeDecoder()
    let encoder = A2AJSON.makeEncoder()

    func wrapperKey(_ value: StreamResponse) throws -> String {
        let data = try encoder.encode(value)
        let object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        return object.keys.first ?? ""
    }

    func roundTrip(_ value: StreamResponse) throws -> StreamResponse {
        try decoder.decode(StreamResponse.self, from: try encoder.encode(value))
    }

    @Test func streamResponseWithTask() throws {
        let value = StreamResponse.task(
            A2ATask(id: "task-1", contextId: "ctx-1", status: TaskStatus(state: .working))
        )
        #expect(try wrapperKey(value) == "task")
        guard case .task(let task) = try roundTrip(value) else { Issue.record("expected task"); return }
        #expect(task.id == "task-1")
    }

    @Test func streamResponseWithMessage() throws {
        let value = StreamResponse.message(
            Message(messageId: "msg-1", role: .agent, parts: [.text("Hello")])
        )
        #expect(try wrapperKey(value) == "message")
        guard case .message(let message) = try roundTrip(value) else { Issue.record("expected message"); return }
        #expect(message.messageId == "msg-1")
    }

    @Test func streamResponseWithStatusUpdate() throws {
        let value = StreamResponse.statusUpdate(
            TaskStatusUpdateEvent(taskId: "task-1", contextId: "ctx-1", status: TaskStatus(state: .working))
        )
        #expect(try wrapperKey(value) == "statusUpdate")
        guard case .statusUpdate(let event) = try roundTrip(value) else { Issue.record("expected statusUpdate"); return }
        #expect(event.taskId == "task-1")
    }

    @Test func streamResponseWithArtifactUpdate() throws {
        let value = StreamResponse.artifactUpdate(
            TaskArtifactUpdateEvent(
                taskId: "task-1", contextId: "ctx-1",
                artifact: Artifact(artifactId: "a-1", parts: [.text("x")])
            )
        )
        #expect(try wrapperKey(value) == "artifactUpdate")
        guard case .artifactUpdate(let event) = try roundTrip(value) else { Issue.record("expected artifactUpdate"); return }
        #expect(event.taskId == "task-1")
    }
}

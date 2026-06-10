import Foundation
import Testing
@testable import A2ACore

/// `StreamResponse.parts` / `.text` の検証。
/// a2a-python の Part 抽出ヘルパ（get_stream_response_text 等）の挙動をミラー：
/// 4 種のペイロードそれぞれから Part を取り出し、テキストを結合する。
@Suite("StreamResponse parts / text extraction")
struct StreamResponsePartsTests {

    @Test("message ペイロード → message.parts")
    func messageParts() {
        let response = StreamResponse.message(
            Message(messageId: MessageID("m"), role: .agent, parts: [.text("hello"), .text("world")])
        )
        #expect(response.parts.compactMap(\.text) == ["hello", "world"])
        #expect(response.text() == "hello\nworld")
    }

    @Test("task ペイロード → artifacts の parts ＋ status.message の parts")
    func taskParts() {
        let task = A2ATask(
            id: TaskID("t"), contextId: ContextID("c"),
            status: TaskStatus(state: .completed, message: Message(messageId: MessageID("s"), role: .agent, parts: [.text("done")])),
            artifacts: [Artifact(artifactId: ArtifactID("a"), parts: [.text("result")])]
        )
        let response = StreamResponse.task(task)
        #expect(response.parts.compactMap(\.text) == ["result", "done"])
        #expect(response.text() == "result\ndone")
    }

    @Test("statusUpdate ペイロード → status.message の parts")
    func statusUpdateParts() {
        let response = StreamResponse.statusUpdate(TaskStatusUpdateEvent(
            taskId: TaskID("t"), contextId: ContextID("c"),
            status: TaskStatus(state: .working, message: Message(messageId: MessageID("s"), role: .agent, parts: [.text("progress")]))
        ))
        #expect(response.parts.compactMap(\.text) == ["progress"])
        #expect(response.text() == "progress")
    }

    @Test("artifactUpdate ペイロード → artifact の parts")
    func artifactUpdateParts() {
        let response = StreamResponse.artifactUpdate(TaskArtifactUpdateEvent(
            taskId: TaskID("t"), contextId: ContextID("c"),
            artifact: Artifact(artifactId: ArtifactID("a"), parts: [.text("chunk")])
        ))
        #expect(response.parts.compactMap(\.text) == ["chunk"])
        #expect(response.text() == "chunk")
    }

    @Test("status メッセージ無しの task は artifacts だけ")
    func taskWithoutStatusMessage() {
        let response = StreamResponse.task(A2ATask(
            id: TaskID("t"), status: TaskStatus(state: .working),
            artifacts: [Artifact(artifactId: ArtifactID("a"), parts: [.text("x")])]
        ))
        #expect(response.text() == "x")
    }
}

import Foundation
import Testing
import StructuredDataCore
@testable import A2ACore

/// 公式仕様 v1.0.1 の例に対する ProtoJSON コンフォーマンス検証。
@Suite("ProtoJSON Conformance")
struct ProtoJSONConformanceTests {
    let decoder = A2AJSON.makeDecoder()
    let encoder = A2AJSON.makeEncoder()

    func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        try decoder.decode(T.self, from: try encoder.encode(value))
    }

    // MARK: - Enums (§5.5)

    @Test func roleSerializesAsProtoName() throws {
        #expect(String(data: try encoder.encode(Role.user), encoding: .utf8) == "\"ROLE_USER\"")
        #expect(try decoder.decode(Role.self, from: Data("\"ROLE_AGENT\"".utf8)) == .agent)
    }

    @Test func unknownEnumFallsBackToUnspecified() throws {
        #expect(try decoder.decode(Role.self, from: Data("\"ROLE_FUTURE\"".utf8)) == .unspecified)
        #expect(try decoder.decode(TaskState.self, from: Data("\"TASK_STATE_WHATEVER\"".utf8)) == .unspecified)
    }

    @Test func taskStateSerialization() throws {
        #expect(String(data: try encoder.encode(TaskState.inputRequired), encoding: .utf8) == "\"TASK_STATE_INPUT_REQUIRED\"")
        #expect(TaskState.completed.isTerminal)
        #expect(TaskState.authRequired.isInterrupted)
    }

    // MARK: - Part (§A.2.1 oneof flattening)

    @Test func textPartHasNoDiscriminator() throws {
        let part = try decoder.decode(Part.self, from: Data(#"{"text":"Hello, world!"}"#.utf8))
        #expect(part.text == "Hello, world!")
        let json = String(data: try encoder.encode(part), encoding: .utf8)!
        #expect(json == #"{"text":"Hello, world!"}"#)
    }

    @Test func filePartFlattened() throws {
        let json = #"{"raw":"aGVsbG8=","filename":"a.txt","mediaType":"text/plain"}"#
        let part = try decoder.decode(Part.self, from: Data(json.utf8))
        #expect(part.bytes == Data("hello".utf8))
        #expect(part.filename == "a.txt")
        #expect(part.mediaType == "text/plain")
        #expect(try roundTrip(part) == part)
    }

    @Test func fileURIPart() throws {
        let part = try decoder.decode(Part.self, from: Data(#"{"url":"https://x/y.png","mediaType":"image/png"}"#.utf8))
        #expect(part.uri == "https://x/y.png")
    }

    @Test func dataPart() throws {
        let part = try decoder.decode(Part.self, from: Data(#"{"data":{"k":1},"mediaType":"application/json"}"#.utf8))
        #expect(part.data == .object(["k": .number(.init(unchecked: "1"))]))
    }

    @Test func partWithoutContentThrows() {
        #expect(throws: (any Error).self) {
            try decoder.decode(Part.self, from: Data(#"{"mediaType":"text/plain"}"#.utf8))
        }
    }

    // MARK: - Message (§6.1)

    @Test func messageDecodesRequiredFields() throws {
        let json = #"{"role":"ROLE_USER","parts":[{"text":"What is the weather today?"}],"messageId":"msg-uuid"}"#
        let message = try decoder.decode(Message.self, from: Data(json.utf8))
        #expect(message.role == .user)
        #expect(message.messageId == "msg-uuid")
        #expect(message.text == "What is the weather today?")
        #expect(try roundTrip(message) == message)
    }

    // MARK: - Task (§6.1)

    @Test func basicTaskResponse() throws {
        let json = """
        {"id":"task-uuid","contextId":"context-uuid","status":{"state":"TASK_STATE_COMPLETED"},
         "artifacts":[{"artifactId":"artifact-uuid","name":"Weather Report",
         "parts":[{"text":"Today will be sunny with a high of 75°F"}]}]}
        """
        let task = try decoder.decode(A2ATask.self, from: Data(json.utf8))
        #expect(task.id == "task-uuid")
        #expect(task.contextId == "context-uuid")
        #expect(task.status.state == .completed)
        #expect(task.artifacts.first?.artifactId == "artifact-uuid")
        #expect(try roundTrip(task) == task)
    }

    // MARK: - Stream responses (§6.2 / §9.4.2)

    @Test func streamResponseTaskVariant() throws {
        let json = #"{"task":{"id":"t","status":{"state":"TASK_STATE_WORKING"}}}"#
        let response = try decoder.decode(StreamResponse.self, from: Data(json.utf8))
        guard case .task(let task) = response else { Issue.record("expected task"); return }
        #expect(task.status.state == .working)
    }

    @Test func streamResponseStatusUpdateVariant() throws {
        let json = #"{"statusUpdate":{"taskId":"t","contextId":"c","status":{"state":"TASK_STATE_COMPLETED"}}}"#
        let response = try decoder.decode(StreamResponse.self, from: Data(json.utf8))
        guard case .statusUpdate(let event) = response else { Issue.record("expected statusUpdate"); return }
        #expect(event.taskId == "t")
        #expect(event.contextId == "c")
    }

    @Test func streamResponseArtifactUpdateVariant() throws {
        let json = #"{"artifactUpdate":{"taskId":"t","contextId":"c","artifact":{"artifactId":"a","parts":[{"text":"x"}]},"lastChunk":true}}"#
        let response = try decoder.decode(StreamResponse.self, from: Data(json.utf8))
        guard case .artifactUpdate(let event) = response else { Issue.record("expected artifactUpdate"); return }
        #expect(event.lastChunk)
        #expect(event.append == false)
    }

    // MARK: - SendMessageResponse (§9.4.1)

    @Test func sendMessageResponseTaskVariant() throws {
        let json = #"{"task":{"id":"t","status":{"state":"TASK_STATE_COMPLETED"}}}"#
        let response = try decoder.decode(SendMessageResponse.self, from: Data(json.utf8))
        guard case .task = response else { Issue.record("expected task"); return }
    }

    @Test func sendMessageResponseMessageVariant() throws {
        let json = #"{"message":{"role":"ROLE_AGENT","parts":[{"text":"hi"}],"messageId":"m"}}"#
        let response = try decoder.decode(SendMessageResponse.self, from: Data(json.utf8))
        guard case .message(let message) = response else { Issue.record("expected message"); return }
        #expect(message.text == "hi")
    }

    // MARK: - Timestamp (§5.6.1)

    @Test func timestampParsesWithAndWithoutFractional() throws {
        let withFrac = try decoder.decode(TaskStatus.self, from: Data(#"{"state":"TASK_STATE_WORKING","timestamp":"2025-10-28T10:30:00.000Z"}"#.utf8))
        #expect(withFrac.timestamp != nil)
        let plain = try decoder.decode(TaskStatus.self, from: Data(#"{"state":"TASK_STATE_WORKING","timestamp":"2023-10-27T10:00:00Z"}"#.utf8))
        #expect(plain.timestamp != nil)
        #expect(try roundTrip(withFrac) == withFrac)
    }

    // MARK: - Sample Agent Card (§8.5)

    @Test func sampleAgentCard() throws {
        let url = Bundle.module.url(forResource: "sample_agent_card", withExtension: "json", subdirectory: "Fixtures")!
        let data = try Data(contentsOf: url)
        let card = try decoder.decode(AgentCard.self, from: data)

        #expect(card.name == "GeoSpatial Route Planner Agent")
        #expect(card.version == "1.2.0")
        #expect(card.supportedInterfaces.count == 3)
        #expect(card.supportedInterfaces.first?.protocolBinding == "JSONRPC")
        #expect(card.supportedInterfaces.first?.protocolVersion == "1.0")
        #expect(card.capabilities.extendedAgentCard == true)
        #expect(card.provider?.organization == "Example Geo Services Inc.")
        #expect(card.iconUrl == "https://georoute-agent.example.com/icon.png")
        #expect(card.skills.count == 2)
        #expect(card.skills.first?.tags.contains("routing") == true)
        #expect(card.security == [["google": ["openid", "profile", "email"]]])
        #expect(card.signatures.count == 1)

        // securitySchemes は ProtoJSON oneof（メンバ名判別）
        guard case .openIdConnect(let scheme) = card.securitySchemes?["google"] else {
            Issue.record("expected openIdConnect scheme"); return
        }
        #expect(scheme.openIdConnectUrl == "https://accounts.google.com/.well-known/openid-configuration")

        // 復号→符号化→復号のべき等性
        #expect(try roundTrip(card) == card)
    }

    // MARK: - SendMessageRequest build + encode (§6.1)

    @Test func buildAndEncodeSendMessageRequest() throws {
        let request = SendMessageRequest(
            message: Message(messageId: "msg-uuid", role: .user) {
                "What is the weather today?"
            }
        )
        let data = try encoder.encode(request)
        let decoded = try decoder.decode(SendMessageRequest.self, from: data)
        #expect(decoded.message.text == "What is the weather today?")
        #expect(decoded.message.role == .user)
    }
}

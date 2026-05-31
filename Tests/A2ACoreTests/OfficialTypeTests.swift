import Foundation
import Testing
import StructuredDataCore
@testable import A2ACore

/// 公式 a2a-python の `tests/test_types.py`（proto JSON / ParseDict・MessageToDict）の
/// fixture と assertion を移植し、proto3 セマンティクスへの一致を検証する。
@Suite("Official type parity (test_types.py)")
struct OfficialTypeTests {
    let decoder = A2AJSON.decoder()
    let encoder = A2AJSON.encoder()

    /// エンコード結果のトップレベルキー集合（MessageToDict の default 省略検証用）。
    func topLevelKeys<T: Encodable>(_ value: T) throws -> Set<String> {
        let data = try encoder.encode(value)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return Set(object.keys)
    }

    // MINIMAL_AGENT_CARD — capabilities は {}、interface は protocolVersion 省略
    static let minimalAgentCard = """
    {
      "capabilities": {},
      "defaultInputModes": ["text/plain"],
      "defaultOutputModes": ["application/json"],
      "description": "Test Agent",
      "name": "TestAgent",
      "skills": [{"id": "skill-123", "name": "Recipe Finder", "description": "Finds recipes", "tags": ["cooking"]}],
      "supportedInterfaces": [{"url": "http://example.com/agent", "protocolBinding": "HTTP+JSON"}],
      "version": "1.0"
    }
    """

    @Test func minimalAgentCardParsesWithProto3Defaults() throws {
        let card = try decoder.decode(AgentCard.self, from: Data(Self.minimalAgentCard.utf8))
        #expect(card.name == "TestAgent")
        #expect(card.version == "1.0")
        #expect(card.skills.count == 1)
        #expect(card.skills.first?.id == "skill-123")
        #expect(card.supportedInterfaces.first?.url == "http://example.com/agent")
        // protocolVersion は欠落 → proto3 既定の空文字列（例外を投げない）
        #expect(card.supportedInterfaces.first?.protocolVersion == "")
        // provider は未設定
        #expect(card.provider == nil)
        // capabilities は {} → 全て未設定
        #expect(card.capabilities.streaming == nil)
        #expect(card.capabilities.extensions.isEmpty)
    }

    @Test func fullAgentSkillRoundTrips() throws {
        let json = """
        {"id":"skill-123","name":"Recipe Finder","description":"Finds recipes",
         "tags":["cooking","food"],"examples":["Find me a pasta recipe"],
         "inputModes":["text/plain"],"outputModes":["application/json"]}
        """
        let skill = try decoder.decode(AgentSkill.self, from: Data(json.utf8))
        #expect(skill.id == "skill-123")
        #expect(skill.examples == ["Find me a pasta recipe"])
        #expect(skill.inputModes == ["text/plain"])
        let reDecoded = try decoder.decode(AgentSkill.self, from: try encoder.encode(skill))
        #expect(reDecoded == skill)
    }

    // MessageToDict は default 値を省略する（test_message_to_dict_preserves_structure）
    @Test func messageToDictOmitsDefaults() throws {
        let message = Message(messageId: "msg-123", role: .user, parts: [.text("Hello")])
        #expect(try topLevelKeys(message) == ["role", "messageId", "parts"])

        let data = try encoder.encode(message)
        let object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(object["role"] as? String == "ROLE_USER")
        #expect(object["messageId"] as? String == "msg-123")
        let parts = object["parts"] as! [[String: Any]]
        #expect(parts[0]["text"] as? String == "Hello")
        #expect(parts[0].keys.count == 1)   // text のみ
    }

    // 空メッセージ → proto3 既定値（test_default_values）
    @Test func emptyMessageDecodesToDefaults() throws {
        let message = try decoder.decode(Message.self, from: Data("{}".utf8))
        #expect(message.role == .unspecified)
        #expect(message.messageId.rawValue == "")
        #expect(message.parts.isEmpty)
    }

    @Test func emptyTaskStatusDecodesToUnspecified() throws {
        let status = try decoder.decode(TaskStatus.self, from: Data("{}".utf8))
        #expect(status.state == .unspecified)
        #expect(status.message == nil)
        #expect(status.timestamp == nil)
    }

    // ParseDict Task with nested history（test_parse_dict_task）
    @Test func parseDictTaskWithHistory() throws {
        let json = """
        {"id":"task-123","contextId":"ctx-456","status":{"state":"TASK_STATE_WORKING"},
         "history":[{"role":"ROLE_USER","messageId":"msg-1","parts":[{"text":"Hello"}]}]}
        """
        let task = try decoder.decode(A2ATask.self, from: Data(json.utf8))
        #expect(task.id == "task-123")
        #expect(task.contextId == "ctx-456")
        #expect(task.status.state == .working)
        #expect(task.history.count == 1)
        #expect(task.history.first?.role == .user)
    }

    // Part 各種（test_part_with_url / _raw / _data）
    @Test func partVariants() throws {
        let url = try decoder.decode(Part.self, from: Data(#"{"url":"file:///path/to/file.txt","mediaType":"text/plain"}"#.utf8))
        #expect(url.uri == "file:///path/to/file.txt")
        #expect(url.mediaType == "text/plain")

        let raw = try decoder.decode(Part.self, from: Data(#"{"raw":"aGVsbG8=","filename":"hello.txt"}"#.utf8))
        #expect(raw.bytes == Data("hello".utf8))
        #expect(raw.filename == "hello.txt")

        let data = try decoder.decode(Part.self, from: Data(#"{"data":{"key":"value"}}"#.utf8))
        #expect(data.data == .object(["key": "value"]))
    }

    // enum の文字列表現（test_role_enum / test_task_state_enum）
    @Test func enumProtoNames() {
        #expect(Role.unspecified.rawValue == "ROLE_UNSPECIFIED")
        #expect(Role.user.rawValue == "ROLE_USER")
        #expect(Role.agent.rawValue == "ROLE_AGENT")
        #expect(TaskState.submitted.rawValue == "TASK_STATE_SUBMITTED")
        #expect(TaskState.inputRequired.rawValue == "TASK_STATE_INPUT_REQUIRED")
        #expect(TaskState.rejected.rawValue == "TASK_STATE_REJECTED")
        #expect(TaskState.authRequired.rawValue == "TASK_STATE_AUTH_REQUIRED")
    }

    // SecurityScheme oneof（test_security_scheme）
    @Test func securitySchemeApiKeyOneof() throws {
        let json = #"{"apiKeySecurityScheme":{"name":"X-API-KEY","location":"header"}}"#
        let scheme = try decoder.decode(SecurityScheme.self, from: Data(json.utf8))
        guard case .apiKey(let apiKey) = scheme else { Issue.record("expected apiKey"); return }
        #expect(apiKey.name == "X-API-KEY")
        #expect(apiKey.location == .header)
    }

    // Task with artifact + data part（test_task_with_artifacts）
    @Test func taskWithArtifactDataPart() throws {
        let json = """
        {"id":"task-abc","contextId":"session-xyz","status":{"state":"TASK_STATE_COMPLETED"},
         "artifacts":[{"artifactId":"artifact-123","name":"result","parts":[{"data":{"result":42}}]}]}
        """
        let task = try decoder.decode(A2ATask.self, from: Data(json.utf8))
        #expect(task.artifacts.count == 1)
        #expect(task.artifacts.first?.artifactId == "artifact-123")
        #expect(task.artifacts.first?.name == "result")
        #expect(task.artifacts.first?.parts.first?.data == .object(["result": 42]))
    }
}

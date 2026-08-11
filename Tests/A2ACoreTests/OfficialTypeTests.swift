import Foundation
import Testing
import StructuredDataCore
@testable import A2ACore

/// Ports the fixtures and assertions of the reference implementation's type tests, checking that
/// this encoding matches proto3 JSON semantics in both directions.
@Suite("Official type parity (test_types.py)")
struct OfficialTypeTests {
    let decoder = A2AJSON.makeDecoder()
    let encoder = A2AJSON.makeEncoder()

    /// The top-level keys of the encoded form, for asserting which defaults were omitted.
    func topLevelKeys<T: Encodable>(_ value: T) throws -> Set<String> {
        let data = try encoder.encode(value)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return Set(object.keys)
    }

    // The minimal card: empty capabilities, and an interface with no protocolVersion.
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
        // A missing protocolVersion decodes to the proto3 default, the empty string, rather than throwing.
        #expect(card.supportedInterfaces.first?.protocolVersion == "")
        // No provider on this card.
        #expect(card.provider == nil)
        // An empty capabilities object leaves every flag unset.
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

    // Encoding omits fields equal to their proto3 default.
    @Test func messageToDictOmitsDefaults() throws {
        let message = Message(messageId: "msg-123", role: .user, parts: [.text("Hello")])
        #expect(try topLevelKeys(message) == ["role", "messageId", "parts"])

        let data = try encoder.encode(message)
        let object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(object["role"] as? String == "ROLE_USER")
        #expect(object["messageId"] as? String == "msg-123")
        let parts = object["parts"] as! [[String: Any]]
        #expect(parts[0]["text"] as? String == "Hello")
        #expect(parts[0].keys.count == 1)   // Only the text member.
    }

    // An empty message decodes to proto3 defaults throughout.
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

    // A task decoded with its nested history intact.
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

    // Each part content kind: url, raw and data.
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

    // Enums travel as their Protocol Buffer names.
    @Test func enumProtoNames() {
        #expect(Role.unspecified.rawValue == "ROLE_UNSPECIFIED")
        #expect(Role.user.rawValue == "ROLE_USER")
        #expect(Role.agent.rawValue == "ROLE_AGENT")
        #expect(TaskState.submitted.rawValue == "TASK_STATE_SUBMITTED")
        #expect(TaskState.inputRequired.rawValue == "TASK_STATE_INPUT_REQUIRED")
        #expect(TaskState.rejected.rawValue == "TASK_STATE_REJECTED")
        #expect(TaskState.authRequired.rawValue == "TASK_STATE_AUTH_REQUIRED")
    }

    // The security scheme oneof, discriminated by member name.
    @Test func securitySchemeApiKeyOneof() throws {
        let json = #"{"apiKeySecurityScheme":{"name":"X-API-KEY","location":"header"}}"#
        let scheme = try decoder.decode(SecurityScheme.self, from: Data(json.utf8))
        guard case .apiKey(let apiKey) = scheme else { Issue.record("expected apiKey"); return }
        #expect(apiKey.name == "X-API-KEY")
        #expect(apiKey.location == .header)
    }

    // A task carrying an artifact whose part is structured data.
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

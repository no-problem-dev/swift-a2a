/// Who sent a message, serialized as the Protocol Buffer enum name (`ROLE_USER`, `ROLE_AGENT`).
public enum Role: String, ProtoEnum {
    /// The absent or unrecognized value. Decoding any name this enum does not know lands here,
    /// and encoding it omits the field entirely.
    case unspecified = "ROLE_UNSPECIFIED"
    /// Sent by the client that made the request.
    case user = "ROLE_USER"
    /// Sent by the agent answering it.
    case agent = "ROLE_AGENT"
}

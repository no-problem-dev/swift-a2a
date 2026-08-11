/// An enum written on the wire as its Protocol Buffer name, such as `ROLE_USER` or
/// `TASK_STATE_INPUT_REQUIRED` (spec §5.5).
///
/// Decoding never fails on an unrecognized name: it yields `unspecified`, which is what keeps a
/// client working against an agent that has learned a new state (spec §5.7, ignore unrecognized).
///
/// That tolerance is lossy in one direction. An unrecognized value becomes `unspecified`, and
/// encoding omits `unspecified` entirely, so relaying a decoded value back to a peer silently
/// drops the field. Do not use this type to proxy payloads verbatim.
public protocol ProtoEnum: RawRepresentable, Codable, Sendable, Hashable, CaseIterable
where RawValue == String {
    /// The case that unrecognized and absent values decode to, and that encoding omits.
    static var unspecified: Self { get }
}

extension ProtoEnum {
    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? Self.unspecified
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

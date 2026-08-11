import StructuredDataCore

/// Free-form JSON attached to a message, task, artifact or extension — the A2A spelling of
/// `google.protobuf.Struct`.
///
/// Always an object at the top level; the values inside may be anything JSON allows. A2A places no
/// meaning on the contents, so two agents must agree out of band on what they put here.
public typealias A2AMetadata = [String: StructuredValue]

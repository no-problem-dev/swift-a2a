/// Fixed values from the A2A specification: the version this package targets, the well-known
/// path, the two media types, and the two custom header names.
public enum A2AProtocol {
    /// The specification revision this package implements, sent on every client request.
    ///
    /// This is the spec revision (`1.0.1`), which is finer-grained than the major protocol version
    /// an agent advertises in `AgentInterface.protocolVersion` (`1.0`). Do not compare the two.
    public static let version = "1.0.1"

    /// Where an agent publishes its card, relative to the host root (spec §14.3).
    ///
    /// Absolute: the client replaces the whole path of its base URL with this, discarding any
    /// path prefix the endpoint carries.
    public static let agentCardWellKnownPath = "/.well-known/agent-card.json"

    /// The media type of the JSON-RPC binding, and of push-notification deliveries.
    public static let jsonContentType = "application/json"

    /// The media type of the HTTP+JSON binding (spec §14.1), distinct from plain `application/json`.
    public static let a2aJSONContentType = "application/a2a+json"

    /// The header carrying the protocol version (spec §14.2.1).
    public static let versionHeader = "A2A-Version"

    /// The header carrying opted-in extension URIs, comma-separated (spec §14.2.2).
    public static let extensionsHeader = "A2A-Extensions"
}

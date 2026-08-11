import A2ACore

/// Who is calling, carried through every layer of a request.
///
/// The transport dispatchers do not populate this — they default it — so authentication belongs in
/// the HTTP layer that builds the context before handing bytes to a dispatcher. Leaving it at its
/// default puts every caller in one shared owner scope, which is the right choice only for a
/// single-tenant deployment.
public struct ServerCallContext: Sendable {
    /// The authenticated caller, if the HTTP layer identified one. `nil` means unauthenticated.
    public var user: ServerUser?
    /// Arbitrary values the HTTP layer wants to pass to the executor.
    public var state: [String: String]
    /// Extension URIs the caller asked for, from the extensions header.
    public var requestedExtensions: Set<String>
    /// Extension URIs the agent actually honoured. Populated by the executor, not the framework.
    public var activatedExtensions: Set<String>

    public init(
        user: ServerUser? = nil,
        state: [String: String] = [:],
        requestedExtensions: Set<String> = [],
        activatedExtensions: Set<String> = []
    ) {
        self.user = user
        self.state = state
        self.requestedExtensions = requestedExtensions
        self.activatedExtensions = activatedExtensions
    }
}

/// The caller's identity.
///
/// The username doubles as the owner scope keying the in-memory stores, so two callers sharing a
/// username share their tasks.
public struct ServerUser: Sendable, Hashable {
    /// Whether the HTTP layer verified this identity.
    public var isAuthenticated: Bool
    /// The caller's identifier. `nil` falls into the same shared scope as an unauthenticated call.
    public var username: String?

    public init(isAuthenticated: Bool = false, username: String? = nil) {
        self.isAuthenticated = isAuthenticated
        self.username = username
    }
}

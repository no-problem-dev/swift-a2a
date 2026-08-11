/// Derives the storage scope a caller may see, which is how one agent serves many clients without
/// leaking tasks between them (spec §254, §13.1).
///
/// Stores partition by the returned string and never look across partitions, so a resolver that
/// returns a constant makes every task visible to everyone.
public typealias OwnerResolver = @Sendable (ServerCallContext) -> String

/// Scopes by authenticated username, putting every unauthenticated caller in one shared partition.
///
/// The default for the in-memory stores. Since the transport dispatchers do not populate the call
/// context, this yields a single shared scope unless the HTTP layer sets a user — which is
/// adequate for a single-tenant agent and wrong for anything else.
public let resolveUserScope: OwnerResolver = { $0.user?.username ?? "" }

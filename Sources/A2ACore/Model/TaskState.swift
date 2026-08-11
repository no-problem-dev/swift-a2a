/// Where a task is in its lifecycle, serialized as the Protocol Buffer enum name
/// (`TASK_STATE_SUBMITTED`, …).
///
/// States divide into three groups: terminal, from which a task never moves again; interrupted,
/// where the task waits on the client and execution resumes once it responds; and the rest, which
/// are transient.
public enum TaskState: String, ProtoEnum {
    /// The absent or unrecognized value. Decoding any name this enum does not know lands here,
    /// and encoding it omits the field entirely.
    case unspecified = "TASK_STATE_UNSPECIFIED"
    /// Accepted, not started.
    case submitted = "TASK_STATE_SUBMITTED"
    /// Being worked on.
    case working = "TASK_STATE_WORKING"
    /// Finished successfully. Terminal.
    case completed = "TASK_STATE_COMPLETED"
    /// Stopped by an error. Terminal.
    case failed = "TASK_STATE_FAILED"
    /// Stopped on request before finishing. Terminal.
    case canceled = "TASK_STATE_CANCELED"
    /// Waiting for the client to supply more input; execution resumes when it arrives. Interrupted.
    case inputRequired = "TASK_STATE_INPUT_REQUIRED"
    /// Declined by the agent, which will not attempt the work. Terminal.
    case rejected = "TASK_STATE_REJECTED"
    /// Waiting for the client to authenticate before work can continue. Interrupted.
    case authRequired = "TASK_STATE_AUTH_REQUIRED"

    /// Whether the task has stopped for good: completed, failed, canceled or rejected.
    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .canceled, .rejected: true
        default: false
        }
    }

    /// Whether the task is waiting on the client: input-required or auth-required.
    public var isInterrupted: Bool {
        switch self {
        case .inputRequired, .authRequired: true
        default: false
        }
    }
}

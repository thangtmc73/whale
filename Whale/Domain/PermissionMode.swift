import Foundation

/// User-facing setting controlling how file edits/commands are approved.
/// `.approveEachEdit` is intentionally not wired up yet: it requires verifying each
/// provider's live stdin-approval protocol, which M1 does not depend on.
enum PermissionMode: String, Codable, CaseIterable {
    case autoAccept
    case approveEachEdit

    var displayName: String {
        switch self {
        case .autoAccept: return "Auto-accept edits"
        case .approveEachEdit: return "Approve each edit"
        }
    }

    var isAvailable: Bool {
        switch self {
        case .autoAccept: return true
        case .approveEachEdit: return false
        }
    }
}

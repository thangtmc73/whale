import Foundation

enum AgentProvider: String, Codable, CaseIterable, Identifiable {
    case claude
    case codex
    case cursor

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        }
    }

    /// Candidate executable names to resolve on PATH, in priority order.
    var executableNames: [String] {
        switch self {
        case .claude: return ["claude"]
        case .codex: return ["codex"]
        case .cursor: return ["cursor-agent"]
        }
    }

    var iconName: String {
        switch self {
        case .claude: return "sparkles"
        case .codex: return "chevron.left.forwardslash.chevron.right"
        case .cursor: return "cursorarrow.rays"
        }
    }
}

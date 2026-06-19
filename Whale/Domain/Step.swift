import Foundation

/// How to safely undo an edit, if at all. `oldText`'s meaning differs by provider/tool, so a
/// revert can't just "write oldText to the file" blindly — see each case's doc.
enum RevertStrategy: Hashable {
    /// `oldText` is the *entire* original file content (Cursor's editToolCall/writeToolCall
    /// report full before/after snapshots) — safe to write back verbatim.
    case overwriteWholeFile
    /// `oldText`/`newText` are a find/replace pair *within* the file (Claude's Edit tool reports
    /// `old_string`/`new_string`, not the whole file) — reverting must replace `newText` back
    /// with `oldText` in the file's current content, never overwrite the whole file with just
    /// the old substring, or the rest of the file would be destroyed.
    case replaceSubstring
}

struct FileDiff: Hashable {
    var path: String
    var oldText: String?
    var newText: String?
    var unifiedDiff: String?
    /// nil means there's no safe way to revert this edit (e.g. Claude's Write/MultiEdit tools
    /// don't report a "before" state at all) — Discard must be hidden in that case, not guessed at.
    var revertStrategy: RevertStrategy?
    var decision: FileEditDecision = .pending
}

enum FileEditDecision: Hashable {
    case pending, kept, discarded
}

enum StepKind {
    case assistantText(String)
    case thinking(String)
    case toolCall(name: String, inputJSON: String, callID: String)
    case toolResult(forCallID: String, output: String, isError: Bool)
    case fileEdit(FileDiff)
    case bashCommand(command: String, output: String?, exitCode: Int32?, isRunning: Bool)
    case approvalRequest(toolName: String, inputJSON: String, requestID: String)
    case systemNotice(String)
    case error(String)
    /// Never throw on unrecognized line types — surface as a collapsed raw blob instead.
    case unknown(raw: String)
}

struct Step: Identifiable {
    let id: UUID = UUID()
    let timestamp: Date
    var kind: StepKind

    init(timestamp: Date = .now, kind: StepKind) {
        self.timestamp = timestamp
        self.kind = kind
    }
}

struct Turn: Identifiable {
    let id: UUID = UUID()
    let promptText: String
    let startedAt: Date
    var steps: [Step] = []
    var completedAt: Date?
    var failed: Bool = false

    init(promptText: String, startedAt: Date = .now) {
        self.promptText = promptText
        self.startedAt = startedAt
    }
}

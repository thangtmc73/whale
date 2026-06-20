import Foundation
import Observation

@Observable
final class SessionViewModel {
    private(set) var turns: [Turn] = []
    private(set) var isStreaming: Bool = false
    private(set) var lastErrorMessage: String?
    /// Raw, unparsed stdout lines from the underlying CLI — exactly what the process emitted, shown
    /// verbatim in the sidebar terminal so the user can see what's actually running beneath the
    /// formatted timeline. Capped to a rolling tail to keep memory/scroll bounded.
    private(set) var rawLog: [String] = []
    private static let rawLogLimit = 2000
    /// Unsent prompt text, kept per-session (not per-View) so it survives switching between
    /// sessions in the sidebar, and so a cross-provider switch can prefill the handoff text.
    var draftText: String = ""

    let project: Project
    private(set) var session: Session
    var selectedModel: ModelOption

    /// Set by AppViewModel: performs the actual cross-provider transition (creating a new
    /// Session under the chosen provider, auto-forwarding the handoff markdown and carrying the
    /// title over). SessionViewModel can't do this itself — it doesn't own the project's session
    /// list.
    var onSwitchProvider: ((AgentProvider, String, String?) -> Void)?

    private let cliService: AgentCLIService
    private var streamTask: Task<Void, Never>?
    private let onSessionUpdated: (Session) -> Void

    init(
        session: Session,
        project: Project,
        model: ModelOption? = nil,
        onSessionUpdated: @escaping (Session) -> Void = { _ in }
    ) {
        self.session = session
        self.project = project
        self.selectedModel = model ?? ModelCatalog.defaultOption(for: session.provider)
        self.onSessionUpdated = onSessionUpdated
        switch session.provider {
        case .claude:
            self.cliService = ClaudeCLIService()
        case .cursor:
            self.cliService = CursorCLIService()
        case .codex:
            self.cliService = CodexCLIService()
        }
    }

    var availableModels: [ModelOption] {
        ModelCatalog.options(for: session.provider)
    }

    func send(prompt: String, attachments: [URL] = []) {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isStreaming else { return }

        lastErrorMessage = nil
        isStreaming = true
        if session.displayName == nil {
            session.displayName = Self.deriveTitle(from: prompt)
        }
        session.lastModel = selectedModel.id
        session.lastActivityAt = .now
        onSessionUpdated(session)

        let turn = Turn(promptText: prompt, attachments: attachments)
        let turnIndex = turns.count
        turns.append(turn)

        streamTask = Task {
            let stream = cliService.sendTurn(
                prompt: prompt,
                in: project.path,
                session: session,
                model: selectedModel,
                permissionMode: .autoAccept,
                onRawLine: { [weak self] line in
                    self?.appendRawLog(line)
                },
                onResolveCLISessionID: { [weak self] resolvedID in
                    guard let self else { return }
                    self.session.cliSessionID = resolvedID
                    self.session.hasBeenStarted = true
                    self.onSessionUpdated(self.session)
                }
            )
            do {
                for try await step in stream {
                    turns[turnIndex].steps.append(step)
                }
                turns[turnIndex].completedAt = .now
            } catch {
                turns[turnIndex].failed = true
                turns[turnIndex].completedAt = .now
                turns[turnIndex].steps.append(Step(kind: .error("\(error)")))
                lastErrorMessage = "\(error)"
            }
            isStreaming = false
            session.lastActivityAt = .now
            onSessionUpdated(session)
        }
    }

    func cancel() {
        cliService.cancelCurrentTurn()
        streamTask?.cancel()
        isStreaming = false
    }

    /// Splits on embedded newlines (a single yielded line can carry several) and trims to the
    /// rolling tail so a long-running session's terminal doesn't grow without bound.
    private func appendRawLog(_ line: String) {
        let pieces = line.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        rawLog.append(contentsOf: pieces)
        if rawLog.count > Self.rawLogLimit {
            rawLog.removeFirst(rawLog.count - Self.rawLogLimit)
        }
    }

    /// Switching model within the same provider is zero-friction: just update selectedModel,
    /// the next send() resumes the same cliSessionID with the new model.
    func switchModel(to model: ModelOption) {
        selectedModel = model
    }

    /// Switching provider can't resume natively, so this always results in a new Session
    /// (handled by AppViewModel via onSwitchProvider), which auto-sends the handoff markdown to
    /// it immediately — no manual re-send required. `carryForwardContext` controls whether the
    /// full conversation (every prompt + answer) is exported and forwarded, or the new session
    /// starts empty. The title carries over too, since deriving a title from the handoff dump's
    /// first line would produce something useless like "Continuing from a previous session".
    func requestProviderSwitch(to newProvider: AgentProvider, carryForwardContext: Bool) {
        let handoff = carryForwardContext ? buildContextHandoff() : ""
        let title = carryForwardContext ? session.displayName : nil
        onSwitchProvider?(newProvider, handoff, title)
    }

    /// Full markdown export of every prompt and every assistant answer in this session — not
    /// just the last few turns — so the new provider has the complete conversation to work from.
    private func buildContextHandoff() -> String {
        guard !turns.isEmpty else { return "" }
        let body = turns.map { turn -> String in
            let assistantText = turn.steps.compactMap { step -> String? in
                if case .assistantText(let text) = step.kind { return text }
                return nil
            }.joined(separator: "\n\n")
            var block = "**You:** \(turn.promptText)"
            if !assistantText.isEmpty {
                block += "\n\n**\(session.provider.displayName):** \(assistantText)"
            }
            return block
        }.joined(separator: "\n\n---\n\n")
        return """
        _Continuing from a previous \(session.provider.displayName) session — full conversation history below._

        \(body)

        ---
        """
    }

    private static func deriveTitle(from prompt: String) -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.components(separatedBy: "\n").first ?? trimmed
        return firstLine.count > 60 ? String(firstLine.prefix(60)) + "…" : firstLine
    }

    /// "Keep" just records the choice (the edit already happened on disk via the CLI's own
    /// auto-accept). "Discard" additionally reverts the file using whatever `revertStrategy` the
    /// parser determined was safe for that specific edit — never called when revertStrategy is
    /// nil (the view hides Discard in that case).
    func decideFileEdit(stepID: UUID, decision: FileEditDecision) {
        for turnIndex in turns.indices {
            guard let stepIndex = turns[turnIndex].steps.firstIndex(where: { $0.id == stepID }) else { continue }
            guard case .fileEdit(var diff) = turns[turnIndex].steps[stepIndex].kind else { return }
            diff.decision = decision
            if decision == .discarded {
                revertFileEdit(diff)
            }
            turns[turnIndex].steps[stepIndex].kind = .fileEdit(diff)
            return
        }
    }

    private func revertFileEdit(_ diff: FileDiff) {
        guard let strategy = diff.revertStrategy, let oldText = diff.oldText else { return }
        let url = diff.path.hasPrefix("/") ? URL(fileURLWithPath: diff.path) : project.path.appendingPathComponent(diff.path)

        switch strategy {
        case .overwriteWholeFile:
            try? oldText.write(to: url, atomically: true, encoding: .utf8)
        case .replaceSubstring:
            guard let newText = diff.newText,
                  let currentContent = try? String(contentsOf: url, encoding: .utf8),
                  currentContent.contains(newText) else { return }
            let reverted = currentContent.replacingOccurrences(of: newText, with: oldText)
            try? reverted.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

import SwiftUI

struct StepRowView: View {
    let step: Step
    var onFileEditDecision: (UUID, FileEditDecision) -> Void = { _, _ in }

    var body: some View {
        switch step.kind {
        case .assistantText(let text):
            MarkdownTextView(raw: text)

        case .thinking(let text):
            Label(text, systemImage: "brain")
                .font(WhaleTheme.Typography.caption())
                .foregroundStyle(WhaleTheme.Color.muted)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .toolCall(let name, let inputJSON, _):
            DisclosureGroup {
                CopyableCodeBlock(text: inputJSON, language: "json")
            } label: {
                Label("Tool: \(name)", systemImage: "wrench.and.screwdriver")
                    .font(WhaleTheme.Typography.caption())
                    .foregroundStyle(WhaleTheme.Color.muted)
            }
            .tint(WhaleTheme.Color.secondary)

        case .toolResult(_, let output, let isError):
            DisclosureGroup {
                CopyableCodeBlock(text: output)
            } label: {
                Label(isError ? "Tool result (error)" : "Tool result", systemImage: isError ? "exclamationmark.triangle" : "checkmark.circle")
                    .font(WhaleTheme.Typography.caption())
                    .foregroundStyle(isError ? .red : WhaleTheme.Color.muted)
            }
            .tint(WhaleTheme.Color.secondary)

        case .fileEdit(let diff):
            VStack(alignment: .leading, spacing: WhaleTheme.Spacing.xs) {
                HStack {
                    Label(diff.path, systemImage: "doc.text")
                        .font(WhaleTheme.Typography.caption().bold())
                        .foregroundStyle(WhaleTheme.Color.text)
                    Spacer()
                    fileEditDecisionControl(diff)
                }
                if let unifiedDiff = diff.unifiedDiff {
                    DiffCodeBlock(text: unifiedDiff)
                } else if let newText = diff.newText {
                    CopyableCodeBlock(text: newText, language: languageHint(for: diff.path))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .bashCommand(let command, let output, let exitCode, let isRunning):
            VStack(alignment: .leading, spacing: WhaleTheme.Spacing.xs) {
                Label("Bash", systemImage: "terminal")
                    .font(WhaleTheme.Typography.caption().bold())
                    .foregroundStyle(WhaleTheme.Color.text)
                CopyableCodeBlock(text: command, language: "shell")
                if let output {
                    CopyableCodeBlock(text: output)
                } else if isRunning {
                    Text("Running…").font(WhaleTheme.Typography.caption()).foregroundStyle(WhaleTheme.Color.muted)
                }
                if let exitCode, exitCode != 0 {
                    Text("Exit code \(exitCode)").font(WhaleTheme.Typography.caption()).foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .approvalRequest(let toolName, _, _):
            Label("Waiting for approval: \(toolName)", systemImage: "hand.raised")
                .font(WhaleTheme.Typography.caption())
                .foregroundStyle(.orange)

        case .systemNotice(let text):
            Text(text)
                .font(WhaleTheme.Typography.caption(10))
                .foregroundStyle(WhaleTheme.Color.muted.opacity(0.7))

        case .error(let message):
            HStack(alignment: .top, spacing: WhaleTheme.Spacing.xs) {
                Image(systemName: "xmark.octagon.fill")
                Text(message)
                    .textSelection(.enabled)
            }
            .font(WhaleTheme.Typography.caption())
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)

        case .unknown(let raw):
            DisclosureGroup {
                CopyableCodeBlock(text: raw)
            } label: {
                Text("Unrecognized event")
                    .font(WhaleTheme.Typography.caption(10))
                    .foregroundStyle(WhaleTheme.Color.muted.opacity(0.7))
            }
            .tint(WhaleTheme.Color.secondary)
        }
    }

    @ViewBuilder
    private func fileEditDecisionControl(_ diff: FileDiff) -> some View {
        if diff.revertStrategy == nil {
            // No safe way to revert this particular edit (e.g. Claude's Write/MultiEdit tools
            // don't report a "before" state) — showing a Discard button that can't actually undo
            // anything would be worse than not showing one at all.
            EmptyView()
        } else {
            switch diff.decision {
            case .pending:
                HStack(spacing: 10) {
                    Button("Discard") { onFileEditDecision(step.id, .discarded) }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red.opacity(0.85))
                    Button("Keep") { onFileEditDecision(step.id, .kept) }
                        .buttonStyle(.plain)
                        .foregroundStyle(WhaleTheme.Color.secondary)
                }
                .font(.system(size: 10, weight: .semibold))
            case .kept:
                Label("Kept", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WhaleTheme.Color.secondary)
            case .discarded:
                Label("Discarded", systemImage: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.orange)
            }
        }
    }

    private func languageHint(for path: String) -> String? {
        switch (path as NSString).pathExtension.lowercased() {
        case "swift": return "swift"
        case "js", "jsx", "mjs": return "javascript"
        case "ts", "tsx": return "typescript"
        case "py": return "python"
        case "sh", "bash", "zsh": return "bash"
        case "go": return "go"
        case "rs": return "rust"
        case "rb": return "ruby"
        case "java", "kt": return "java"
        case "c", "h": return "c"
        case "cpp", "cc", "hpp": return "cpp"
        case "json": return "json"
        case "yml", "yaml": return "yaml"
        default: return nil
        }
    }
}

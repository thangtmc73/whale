import SwiftUI
import UniformTypeIdentifiers

struct ComposerView: View {
    @Binding var text: String
    let isStreaming: Bool
    let provider: AgentProvider
    let switchableProviders: [AgentProvider]
    let availableModels: [ModelOption]
    let selectedModel: ModelOption
    let onSelectProvider: (AgentProvider) -> Void
    let onSelectModel: (ModelOption) -> Void
    let onSend: (String) -> Void
    let onCancel: () -> Void

    @State private var attachments: [URL] = []
    @State private var isDropTargeted = false

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WhaleTheme.Spacing.sm) {
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(attachments, id: \.self) { url in
                            AttachmentChip(url: url) {
                                removeAttachment(url)
                            }
                        }
                    }
                }
            }

            HStack(alignment: .bottom, spacing: WhaleTheme.Spacing.sm) {
                TextField("Ask Whale to do something…", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(WhaleTheme.Typography.body(14))
                    .foregroundStyle(WhaleTheme.Color.text)
                    .lineLimit(1...6)
                    .disabled(isStreaming)
                    .onKeyPress(.return, phases: .down) { press in
                        guard !press.modifiers.contains(.shift) else { return .ignored }
                        send()
                        return .handled
                    }

                if isStreaming {
                    Button(action: onCancel) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Cancel")
                } else {
                    Button(action: send) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(canSend ? WhaleTheme.Color.gradient : LinearGradient(colors: [WhaleTheme.Color.muted.opacity(0.4)], startPoint: .leading, endPoint: .trailing))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .help("Send (Enter)")
                }
            }

            HStack(spacing: WhaleTheme.Spacing.sm) {
                providerMenu
                modelMenu
                Spacer(minLength: 0)
                Text("Enter to send · Shift+Enter for newline")
                    .font(WhaleTheme.Typography.caption(10))
                    .foregroundStyle(WhaleTheme.Color.muted)
            }
        }
        .padding(WhaleTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: WhaleTheme.Radius.composer)
                .fill(WhaleTheme.Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WhaleTheme.Radius.composer)
                .strokeBorder(isDropTargeted ? WhaleTheme.Color.secondary : WhaleTheme.Color.border, lineWidth: isDropTargeted ? 1.5 : 1)
        )
        .whaleGlow(isDropTargeted ? WhaleTheme.Color.secondary : WhaleTheme.Color.primary, radius: isDropTargeted ? 24 : 14, opacity: isDropTargeted ? 0.25 : 0.10)
        .padding(WhaleTheme.Spacing.md)
        .animation(WhaleTheme.Motion.fast, value: isDropTargeted)
        .onDrop(of: [.fileURL, .url], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private var providerMenu: some View {
        Menu {
            ForEach(switchableProviders) { item in
                Button {
                    onSelectProvider(item)
                } label: {
                    if item == provider {
                        Label(item.displayName, systemImage: "checkmark")
                    } else {
                        Label(item.displayName, systemImage: item.iconName)
                    }
                }
            }
        } label: {
            chipLabel(systemImage: provider.iconName, text: provider.displayName)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Provider")
    }

    private var modelMenu: some View {
        Menu {
            ForEach(availableModels) { model in
                Button {
                    onSelectModel(model)
                } label: {
                    if model.id == selectedModel.id {
                        Label(model.displayName, systemImage: "checkmark")
                    } else {
                        Text(model.displayName)
                    }
                }
            }
        } label: {
            chipLabel(systemImage: "cpu", text: selectedModel.displayName)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Model")
    }

    private func chipLabel(systemImage: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(WhaleTheme.Typography.caption(11))
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(WhaleTheme.Color.muted)
        }
        .foregroundStyle(WhaleTheme.Color.text)
        .padding(.horizontal, WhaleTheme.Spacing.sm)
        .padding(.vertical, 5)
        .background(Capsule().fill(WhaleTheme.Color.surface))
        .overlay(Capsule().strokeBorder(WhaleTheme.Color.border, lineWidth: 1))
    }

    private func send() {
        guard !isStreaming, canSend else { return }
        onSend(composedPrompt())
        text = ""
        attachments = []
    }

    /// Visible inline marker inserted into the text at drop time — plain text (no rich
    /// attachment view), so the typed sentence stays readable while still showing which
    /// attachment was dropped where. The same name+icon also shows as a removable chip below.
    private func token(for url: URL) -> String {
        "📎\(url.lastPathComponent)"
    }

    /// Replaces each attachment's inline token with its real path so Claude's own Read/Glob
    /// tools get an actual filesystem path. If a token was manually deleted from the text but
    /// its chip is still attached, falls back to appending that path at the end instead of
    /// silently dropping it.
    private func composedPrompt() -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var missing: [URL] = []
        for url in attachments {
            let tok = token(for: url)
            if result.contains(tok) {
                result = result.replacingOccurrences(of: tok, with: url.path)
            } else {
                missing.append(url)
            }
        }
        if !missing.isEmpty {
            let trailing = missing.map(\.path).joined(separator: "\n")
            result = result.isEmpty ? trailing : result + "\n\n" + trailing
        }
        return result
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async {
                    insertAttachment(url)
                }
            }
        }
        return true
    }

    private func insertAttachment(_ url: URL) {
        guard !attachments.contains(url) else { return }
        attachments.append(url)
        let needsLeadingSpace = !text.isEmpty && !text.hasSuffix(" ") && !text.hasSuffix("\n")
        text += "\(needsLeadingSpace ? " " : "")\(token(for: url)) "
    }

    private func removeAttachment(_ url: URL) {
        attachments.removeAll { $0 == url }
        let tok = token(for: url)
        if let range = text.range(of: "\(tok) ") {
            text.removeSubrange(range)
        } else if let range = text.range(of: tok) {
            text.removeSubrange(range)
        }
    }
}

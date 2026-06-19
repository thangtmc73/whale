import SwiftUI
import AppKit

/// Monospace text block with a copy-to-clipboard button. Shared by every place a Step shows
/// raw command/code-ish text (bash commands, tool input/output, file diffs, fenced code blocks
/// inside markdown) so copy behavior is consistent everywhere instead of reimplemented per case.
struct CopyableCodeBlock: View {
    let text: String
    var language: String?

    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text((language?.isEmpty == false ? language : nil) ?? "text")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(WhaleTheme.Color.muted)
                    .textCase(.lowercase)
                Spacer()
                Button(action: copy) {
                    HStack(spacing: 4) {
                        Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        Text(didCopy ? "Copied" : "Copy")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(didCopy ? WhaleTheme.Color.secondary : WhaleTheme.Color.muted)
                }
                .buttonStyle(.plain)
                .help(didCopy ? "Copied" : "Copy")
            }
            .padding(.horizontal, WhaleTheme.Spacing.md)
            .padding(.vertical, 8)
            .background(SwiftUI.Color.white.opacity(0.03))

            Divider().overlay(WhaleTheme.Color.border)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(CodeSyntaxHighlighter.highlight(text, language: language))
                    .font(WhaleTheme.Typography.mono())
                    .foregroundStyle(WhaleTheme.Color.text.opacity(0.92))
                    .textSelection(.enabled)
                    .padding(WhaleTheme.Spacing.md)
            }
        }
        .background(SwiftUI.Color.black.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: WhaleTheme.Radius.small))
        .overlay(RoundedRectangle(cornerRadius: WhaleTheme.Radius.small).strokeBorder(WhaleTheme.Color.border, lineWidth: 1))
    }

    private func copy() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        withAnimation(WhaleTheme.Motion.fast) { didCopy = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(WhaleTheme.Motion.fast) { didCopy = false }
        }
    }
}

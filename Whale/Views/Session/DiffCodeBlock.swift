import SwiftUI
import AppKit

/// Renders a unified diff with per-line +/- coloring (green for additions, red for removals,
/// muted for hunk/file headers) instead of as flat monospace text — same copy-button chrome as
/// `CopyableCodeBlock`, just with line-aware rendering for the body.
struct DiffCodeBlock: View {
    let text: String

    @State private var didCopy = false

    private enum LineKind {
        case addition, removal, hunkHeader, fileHeader, context

        var foreground: Color {
            switch self {
            case .addition: return WhaleTheme.Color.diffAddition
            case .removal: return WhaleTheme.Color.diffRemoval
            case .hunkHeader: return WhaleTheme.Color.secondary
            case .fileHeader: return WhaleTheme.Color.muted
            case .context: return WhaleTheme.Color.text.opacity(0.85)
            }
        }

        var background: Color {
            switch self {
            case .addition: return Color(hex: 0x22C55E, opacity: 0.16)
            case .removal: return Color(hex: 0xEF4444, opacity: 0.16)
            default: return .clear
            }
        }
    }

    private static func kind(of line: String) -> LineKind {
        if line.hasPrefix("+++") || line.hasPrefix("---") { return .fileHeader }
        if line.hasPrefix("@@") { return .hunkHeader }
        if line.hasPrefix("+") { return .addition }
        if line.hasPrefix("-") { return .removal }
        return .context
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("diff")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(WhaleTheme.Color.muted)
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
            .background(WhaleTheme.Color.codeHeader)

            Divider().overlay(WhaleTheme.Color.border)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                        let kind = Self.kind(of: line)
                        Text(line.isEmpty ? " " : line)
                            .font(WhaleTheme.Typography.mono())
                            .foregroundStyle(kind.foreground)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, WhaleTheme.Spacing.md)
                            .padding(.vertical, 1)
                            .background(kind.background)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .background(WhaleTheme.Color.codeBackground)
        .clipShape(RoundedRectangle(cornerRadius: WhaleTheme.Radius.small))
        .overlay(RoundedRectangle(cornerRadius: WhaleTheme.Radius.small).strokeBorder(WhaleTheme.Color.border, lineWidth: 1))
        .textSelection(.enabled)
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

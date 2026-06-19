import SwiftUI
import AppKit

struct AddProjectView: View {
    let onPick: (URL) -> Void

    var body: some View {
        VStack(spacing: WhaleTheme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(WhaleTheme.Color.gradient.opacity(0.18))
                    .frame(width: 72, height: 72)
                Image(systemName: "water.waves")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(WhaleTheme.Color.accent)
            }
            .whaleGlow(WhaleTheme.Color.secondary, radius: 24, opacity: 0.2)

            VStack(spacing: WhaleTheme.Spacing.xs) {
                Text("Open a project to start")
                    .font(WhaleTheme.Typography.heading(16))
                    .foregroundStyle(WhaleTheme.Color.text)
                Text("Whale brings Claude, Cursor, and Codex sessions together in one place.")
                    .font(WhaleTheme.Typography.body(12))
                    .foregroundStyle(WhaleTheme.Color.muted)
            }

            Button {
                if let url = FolderPicker.pick() {
                    onPick(url)
                }
            } label: {
                Text("Open Project…")
                    .font(WhaleTheme.Typography.body(13))
                    .foregroundStyle(WhaleTheme.Color.text)
                    .padding(.horizontal, WhaleTheme.Spacing.lg)
                    .padding(.vertical, WhaleTheme.Spacing.sm)
                    .background(RoundedRectangle(cornerRadius: WhaleTheme.Radius.small).fill(WhaleTheme.Color.surface))
                    .overlay(RoundedRectangle(cornerRadius: WhaleTheme.Radius.small).strokeBorder(WhaleTheme.Color.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WhaleTheme.Color.background)
    }
}

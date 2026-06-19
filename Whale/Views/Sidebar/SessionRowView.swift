import SwiftUI

struct SessionRowView: View {
    let session: Session
    let isSelected: Bool

    private var tintColor: Color {
        switch session.provider {
        case .claude: return WhaleTheme.Color.accent
        case .cursor: return WhaleTheme.Color.secondary
        case .codex: return WhaleTheme.Color.primary
        }
    }

    var body: some View {
        HStack(spacing: WhaleTheme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(tintColor.opacity(isSelected ? 0.18 : 0.10))
                Image(systemName: session.provider.iconName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? tintColor : WhaleTheme.Color.muted)
            }
            .frame(width: 26, height: 26)

            Text(session.displayName ?? session.provider.displayName)
                .font(WhaleTheme.Typography.body(13))
                .foregroundStyle(isSelected ? WhaleTheme.Color.text : WhaleTheme.Color.text.opacity(0.85))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, WhaleTheme.Spacing.sm)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: WhaleTheme.Radius.small)
                .fill(isSelected ? WhaleTheme.Color.surfaceSelected : .clear)
        )
        .contentShape(Rectangle())
    }
}

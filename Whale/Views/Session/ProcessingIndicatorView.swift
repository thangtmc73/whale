import SwiftUI

/// A small animated pill shown above the composer while a turn is streaming, and hidden the
/// moment it stops — purely a "something is happening" cue, not a progress percentage (the CLIs
/// don't report one).
struct ProcessingIndicatorView: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(WhaleTheme.Color.secondary)
                        .frame(width: 5, height: 5)
                        .opacity(animate ? 1 : 0.25)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: animate
                        )
                }
            }
            Text("Whale is responding...")
                .font(WhaleTheme.Typography.caption(11))
                .foregroundStyle(WhaleTheme.Color.muted)
        }
        .padding(.horizontal, WhaleTheme.Spacing.md)
        .padding(.vertical, 6)
        .background(Capsule().fill(WhaleTheme.Color.surface))
        .overlay(Capsule().strokeBorder(WhaleTheme.Color.border, lineWidth: 1))
        .onAppear { animate = true }
    }
}

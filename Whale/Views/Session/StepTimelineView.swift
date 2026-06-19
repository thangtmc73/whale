import SwiftUI

struct StepTimelineView: View {
    let turns: [Turn]
    var onFileEditDecision: (UUID, FileEditDecision) -> Void = { _, _ in }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Pinned section headers: while scrolling through a turn's steps, that turn's
                // prompt stays stuck to the top so it's always clear which question the answer
                // below belongs to — swaps to the next prompt once its section reaches the top.
                LazyVStack(alignment: .leading, spacing: WhaleTheme.Spacing.lg, pinnedViews: [.sectionHeaders]) {
                    ForEach(turns) { turn in
                        Section {
                            VStack(alignment: .leading, spacing: WhaleTheme.Spacing.sm) {
                                ForEach(turn.steps) { step in
                                    StepRowView(step: step, onFileEditDecision: onFileEditDecision)
                                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                                }
                            }
                            .padding(.horizontal, WhaleTheme.Spacing.lg)
                        } header: {
                            promptHeader(turn.promptText)
                        }
                        .id(turn.id)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, WhaleTheme.Spacing.lg)
                .animation(WhaleTheme.Motion.normal, value: turns.last?.steps.count)
            }
            .background(WhaleTheme.Color.background)
            .onChange(of: turns.last?.steps.count) {
                withAnimation(WhaleTheme.Motion.fast) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    /// Sits on its own full-bleed opaque background (not just the bubble's) so that when this
    /// header is pinned at the scroll view's top, it fully occludes content scrolling underneath
    /// instead of letting it show through a translucent edge.
    @ViewBuilder
    private func promptHeader(_ text: String) -> some View {
        Text(text)
            .font(WhaleTheme.Typography.body(13))
            .foregroundStyle(WhaleTheme.Color.text)
            .padding(.horizontal, WhaleTheme.Spacing.md)
            .padding(.vertical, WhaleTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: WhaleTheme.Radius.medium)
                    .fill(WhaleTheme.Color.primary.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: WhaleTheme.Radius.medium)
                    .strokeBorder(WhaleTheme.Color.primary.opacity(0.25), lineWidth: 1)
            )
            .padding(.horizontal, WhaleTheme.Spacing.lg)
            .padding(.bottom, WhaleTheme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WhaleTheme.Color.background)
    }
}

import SwiftUI

struct SessionView: View {
    var viewModel: SessionViewModel

    var body: some View {
        VStack(spacing: 0) {
            StepTimelineView(turns: viewModel.turns, onFileEditDecision: viewModel.decideFileEdit)

            if let error = viewModel.lastErrorMessage {
                Text(error)
                    .font(WhaleTheme.Typography.caption())
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .padding(.horizontal, WhaleTheme.Spacing.lg)
                    .padding(.bottom, WhaleTheme.Spacing.xs)
            }

            if viewModel.isStreaming {
                ProcessingIndicatorView()
                    .padding(.horizontal, WhaleTheme.Spacing.lg)
                    .padding(.bottom, WhaleTheme.Spacing.xs)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            ComposerView(
                text: Binding(
                    get: { viewModel.draftText },
                    set: { viewModel.draftText = $0 }
                ),
                isStreaming: viewModel.isStreaming,
                onSend: { prompt in
                    viewModel.send(prompt: prompt)
                },
                onCancel: viewModel.cancel
            )
        }
        .animation(WhaleTheme.Motion.fast, value: viewModel.isStreaming)
        .background(WhaleTheme.Color.background)
    }
}

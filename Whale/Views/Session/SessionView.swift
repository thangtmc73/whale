import SwiftUI

struct SessionView: View {
    var viewModel: SessionViewModel
    @State private var pendingProviderSwitch: AgentProvider?

    private let switchableProviders: [AgentProvider] = [.claude, .cursor, .codex]

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
                provider: viewModel.session.provider,
                switchableProviders: switchableProviders,
                availableModels: viewModel.availableModels,
                selectedModel: viewModel.selectedModel,
                onSelectProvider: { provider in
                    guard provider != viewModel.session.provider else { return }
                    pendingProviderSwitch = provider
                },
                onSelectModel: { viewModel.switchModel(to: $0) },
                onSend: { prompt, attachments in
                    viewModel.send(prompt: prompt, attachments: attachments)
                },
                onCancel: viewModel.cancel
            )
        }
        .animation(WhaleTheme.Motion.fast, value: viewModel.isStreaming)
        .background(WhaleTheme.Color.background)
        .confirmationDialog(
            pendingProviderSwitch.map { "Switch to \($0.displayName)?" } ?? "",
            isPresented: Binding(
                get: { pendingProviderSwitch != nil },
                set: { isPresented in if !isPresented { pendingProviderSwitch = nil } }
            ),
            presenting: pendingProviderSwitch
        ) { provider in
            Button("Carry Forward Context") {
                viewModel.requestProviderSwitch(to: provider, carryForwardContext: true)
                pendingProviderSwitch = nil
            }
            Button("Start Fresh") {
                viewModel.requestProviderSwitch(to: provider, carryForwardContext: false)
                pendingProviderSwitch = nil
            }
            Button("Cancel", role: .cancel) {
                pendingProviderSwitch = nil
            }
        } message: { provider in
            Text("\(provider.displayName) can't resume this conversation directly — a new session will be created, and the full conversation so far will be sent to it automatically.")
        }
    }
}

import SwiftUI

struct SessionView: View {
    var viewModel: SessionViewModel
    @State private var pendingProviderSwitch: AgentProvider?

    /// Codex isn't excluded from the model — it's just not a real switch target yet
    /// (CodexCLIService doesn't exist; CLI isn't installed/verified, see M3 in the plan).
    private let switchableProviders: [AgentProvider] = [.claude, .cursor]

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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(viewModel.availableModels) { model in
                        Button {
                            viewModel.switchModel(to: model)
                        } label: {
                            if model.id == viewModel.selectedModel.id {
                                Label(model.displayName, systemImage: "checkmark")
                            } else {
                                Text(model.displayName)
                            }
                        }
                    }
                } label: {
                    Text(viewModel.selectedModel.displayName)
                }
                .help("Model")
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(switchableProviders) { provider in
                        Button {
                            guard provider != viewModel.session.provider else { return }
                            pendingProviderSwitch = provider
                        } label: {
                            if provider == viewModel.session.provider {
                                Label(provider.displayName, systemImage: "checkmark")
                            } else {
                                Label(provider.displayName, systemImage: provider.iconName)
                            }
                        }
                    }
                } label: {
                    Label(viewModel.session.provider.displayName, systemImage: viewModel.session.provider.iconName)
                }
                .help("Provider")
            }
        }
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
            }
            Button("Start Fresh") {
                viewModel.requestProviderSwitch(to: provider, carryForwardContext: false)
            }
            Button("Cancel", role: .cancel) {}
        } message: { provider in
            Text("\(provider.displayName) can't resume this conversation directly — a new session will be created, and the full conversation so far will be sent to it automatically.")
        }
    }
}

import SwiftUI

struct RootView: View {
    let appViewModel: AppViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility
    @State private var inspectorPresented = false
    @State private var pendingProviderSwitch: AgentProvider?
    
    private let switchableProviders: [AgentProvider] = [.claude, .cursor, .codex]

    init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
        // AppViewModel auto-restores the last-opened project in its own init(), which runs
        // before this view's first render — so `.onChange` below would never see a nil-to-
        // non-nil transition to react to. Seed the initial value directly instead.
        _columnVisibility = State(initialValue: appViewModel.selectedProject != nil ? .all : .detailOnly)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            if appViewModel.selectedProject != nil {
                SessionSidebarView(appViewModel: appViewModel)
            }
        } detail: {
            if let sessionViewModel = appViewModel.selectedSessionViewModel {
                SessionView(viewModel: sessionViewModel)
                    .inspector(isPresented: $inspectorPresented) {
                        SessionInspectorView(viewModel: sessionViewModel)
                            .inspectorColumnWidth(min: 220, ideal: 260, max: 320)
                    }
            } else {
                AddProjectView(onPick: appViewModel.addProject)
            }
        }
        .toolbar {
            if let sessionViewModel = appViewModel.selectedSessionViewModel {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach(sessionViewModel.availableModels) { model in
                            Button {
                                sessionViewModel.switchModel(to: model)
                            } label: {
                                if model.id == sessionViewModel.selectedModel.id {
                                    Label(model.displayName, systemImage: "checkmark")
                                } else {
                                    Text(model.displayName)
                                }
                            }
                        }
                    } label: {
                        Text(sessionViewModel.selectedModel.displayName)
                    }
                    .help("Model")
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach(switchableProviders) { provider in
                            Button {
                                guard provider != sessionViewModel.session.provider else { return }
                                pendingProviderSwitch = provider
                            } label: {
                                if provider == sessionViewModel.session.provider {
                                    Label(provider.displayName, systemImage: "checkmark")
                                } else {
                                    Label(provider.displayName, systemImage: provider.iconName)
                                }
                            }
                        }
                    } label: {
                        Label(sessionViewModel.session.provider.displayName, systemImage: sessionViewModel.session.provider.iconName)
                    }
                    .help("Provider")
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation(WhaleTheme.Motion.normal) {
                            inspectorPresented.toggle()
                        }
                    } label: {
                        Image(systemName: "sidebar.trailing")
                    }
                    .help("Toggle Inspector")
                }
            }
        }
        .navigationTitle(appViewModel.selectedProject?.displayName ?? "Whale")
        .frame(minWidth: 720, minHeight: 480)
        .background(WhaleTheme.Color.background)
        .tint(WhaleTheme.Color.secondary)
        .onChange(of: appViewModel.selectedProject?.id) { _, newValue in
            columnVisibility = newValue != nil ? .all : .detailOnly
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
                appViewModel.selectedSessionViewModel?.requestProviderSwitch(to: provider, carryForwardContext: true)
                pendingProviderSwitch = nil
            }
            Button("Start Fresh") {
                appViewModel.selectedSessionViewModel?.requestProviderSwitch(to: provider, carryForwardContext: false)
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

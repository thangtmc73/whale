import SwiftUI

struct RootView: View {
    let appViewModel: AppViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility
    @State private var inspectorPresented = false

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
                        SessionInspectorView(viewModel: sessionViewModel, gitBranch: appViewModel.currentGitBranch)
                            .inspectorColumnWidth(min: 220, ideal: 260, max: 320)
                    }
                    .toolbar {
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
            } else {
                AddProjectView(onPick: appViewModel.addProject)
            }
        }
        .navigationTitle(appViewModel.selectedProject?.displayName ?? "Whale")
        .navigationSubtitle(appViewModel.currentGitBranch ?? "")
        .frame(minWidth: 720, minHeight: 480)
        .background(WhaleTheme.Color.background)
        .tint(WhaleTheme.Color.secondary)
        .onChange(of: appViewModel.selectedProject?.id) { _, newValue in
            columnVisibility = newValue != nil ? .all : .detailOnly
        }
    }
}

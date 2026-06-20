import SwiftUI

struct RootView: View {
    let appViewModel: AppViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var inspectorPresented = false
    @State private var showSettings = false

    var body: some View {
        content
            .frame(minWidth: 720, minHeight: 480)
            .background(WhaleTheme.Color.background)
            .tint(WhaleTheme.Color.secondary)
            .toolbarBackground(WhaleTheme.Color.background, for: .windowToolbar)
            .toolbarBackground(.visible, for: .windowToolbar)
    }

    /// Three distinct shells. Only the chat shell uses a `NavigationSplitView` — so the automatic
    /// sidebar toggle (which can't be reliably removed per-screen) simply can't appear on the
    /// Settings or Open Folder screens, which use a plain `NavigationStack` with no sidebar.
    @ViewBuilder
    private var content: some View {
        if showSettings {
            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
                    .toolbar { settingsToolbarItem }
            }
        } else if appViewModel.selectedProject == nil {
            NavigationStack {
                AddProjectView(onPick: appViewModel.addProject)
                    .navigationTitle("Whale")
                    .toolbar { settingsToolbarItem }
            }
        } else {
            chatShell
        }
    }

    private var chatShell: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SessionSidebarView(appViewModel: appViewModel)
        } detail: {
            if let sessionViewModel = appViewModel.selectedSessionViewModel {
                SessionView(viewModel: sessionViewModel)
                    .inspector(isPresented: $inspectorPresented) {
                        SessionTerminalView(viewModel: sessionViewModel)
                            .inspectorColumnWidth(min: 260, ideal: 340, max: 520)
                    }
            } else {
                AddProjectView(onPick: appViewModel.addProject)
            }
        }
        .toolbar {
            if appViewModel.selectedSessionViewModel != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation(WhaleTheme.Motion.normal) {
                            inspectorPresented.toggle()
                        }
                    } label: {
                        Image(systemName: "terminal")
                    }
                    .help("Toggle Terminal")
                }
            }
            settingsToolbarItem
        }
        .navigationTitle(appViewModel.selectedProject?.displayName ?? "Whale")
    }

    /// One control for Settings: the gear both opens and closes it (filled while open), so there's
    /// no separate Back/Done button. ⌘, toggles too.
    private var settingsToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                withAnimation(WhaleTheme.Motion.normal) {
                    showSettings.toggle()
                }
            } label: {
                Image(systemName: showSettings ? "gearshape.fill" : "gearshape")
            }
            .help(showSettings ? "Close Settings" : "Settings")
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}

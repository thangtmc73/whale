import SwiftUI

@main
struct WhaleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appViewModel = AppViewModel()
    @AppStorage("appearancePreference") private var appearanceRaw = AppearancePreference.system.rawValue

    private var appearance: AppearancePreference {
        AppearancePreference(rawValue: appearanceRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            RootView(appViewModel: appViewModel)
                .preferredColorScheme(appearance.colorScheme)
                .onAppear { appearance.apply() }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Project…") {
                    if let url = FolderPicker.pick() {
                        appViewModel.addProject(at: url)
                    }
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}

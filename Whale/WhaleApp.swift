import SwiftUI

@main
struct WhaleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(appViewModel: appViewModel)
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

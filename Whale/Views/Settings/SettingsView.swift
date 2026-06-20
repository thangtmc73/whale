import SwiftUI
import AppKit

/// App-wide light/dark override. `.system` follows the OS; the other two pin the appearance via
/// `NSApp.appearance` (covers every window + title-bar chrome) and `preferredColorScheme`.
enum AppearancePreference: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    private var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    /// Source of truth for the whole app — nil lets AppKit follow the system setting.
    func apply() {
        NSApp.appearance = nsAppearance
    }
}

@MainActor
@Observable
final class AccountsViewModel {
    private(set) var statuses: [AgentProvider: AccountStatus] = [:]
    private(set) var busy: Set<AgentProvider> = []

    private let service = CLIAccountService()

    func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            for provider in AgentProvider.allCases {
                group.addTask { await self.refresh(provider) }
            }
        }
    }

    func refresh(_ provider: AgentProvider) async {
        let status = await service.status(for: provider)
        statuses[provider] = status
    }

    func login(_ provider: AgentProvider) {
        service.beginLogin(provider: provider)
    }

    func logout(_ provider: AgentProvider) async {
        busy.insert(provider)
        defer { busy.remove(provider) }
        statuses[provider] = await service.logout(provider: provider)
    }
}

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            AccountsSettingsView()
                .tabItem { Label("Accounts", systemImage: "person.crop.circle") }
        }
        .frame(width: 460, height: 380)
    }
}

private struct GeneralSettingsView: View {
    @AppStorage("appearancePreference") private var appearanceRaw = AppearancePreference.system.rawValue

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }

    var body: some View {
        Form {
            Section("Appearance") {
                Picker(selection: $appearanceRaw) {
                    ForEach(AppearancePreference.allCases) { pref in
                        Label(pref.displayName, systemImage: pref.symbol).tag(pref.rawValue)
                    }
                } label: {
                    Text("Theme")
                }
                .pickerStyle(.segmented)
                .onChange(of: appearanceRaw) { _, newValue in
                    AppearancePreference(rawValue: newValue)?.apply()
                }

                Text("Deep Ocean adapts to light and dark. “System” follows your macOS appearance.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Providers", value: "Claude · Codex · Cursor")
            }
        }
        .formStyle(.grouped)
    }
}

private struct AccountsSettingsView: View {
    @State private var viewModel = AccountsViewModel()

    var body: some View {
        Form {
            Section {
                ForEach(AgentProvider.allCases) { provider in
                    AccountRow(
                        provider: provider,
                        status: viewModel.statuses[provider] ?? .unknown,
                        isBusy: viewModel.busy.contains(provider),
                        onLogin: { viewModel.login(provider) },
                        onLogout: { Task { await viewModel.logout(provider) } }
                    )
                }
            } header: {
                HStack {
                    Text("Accounts")
                    Spacer()
                    Button {
                        Task { await viewModel.refreshAll() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Re-check login status")
                }
            } footer: {
                Text("Whale uses each provider's own CLI for sign-in. Login opens a Terminal window for the browser flow — return here and tap Refresh when done.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { await viewModel.refreshAll() }
    }
}

private struct AccountRow: View {
    let provider: AgentProvider
    let status: AccountStatus
    let isBusy: Bool
    let onLogin: () -> Void
    let onLogout: () -> Void

    var body: some View {
        HStack(spacing: WhaleTheme.Spacing.md) {
            Image(systemName: provider.iconName)
                .font(.system(size: 16))
                .foregroundStyle(WhaleTheme.Color.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                    .font(.body)
                statusLine
            }

            Spacer()

            if isBusy {
                ProgressView().controlSize(.small)
            } else {
                actionButton
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var statusLine: some View {
        switch status.state {
        case .loggedIn:
            Text(status.detail.map { "Signed in · \($0)" } ?? "Signed in")
                .font(.caption)
                .foregroundStyle(.green)
        case .loggedOut:
            Text("Not signed in")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .notInstalled:
            Text("CLI not found on PATH")
                .font(.caption)
                .foregroundStyle(.orange)
        case .unknown:
            Text("Checking…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch status.state {
        case .loggedIn:
            Button("Sign Out", action: onLogout)
        case .loggedOut, .unknown:
            Button("Sign In", action: onLogin)
        case .notInstalled:
            EmptyView()
        }
    }
}

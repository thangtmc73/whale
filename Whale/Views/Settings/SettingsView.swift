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
    enum Activity { case signingIn, signingOut }

    private(set) var statuses: [AgentProvider: AccountStatus] = [:]
    private(set) var activity: [AgentProvider: Activity] = [:]
    /// Sign-in link parsed from the CLI's output, shown as a manual fallback if the browser
    /// didn't open on its own.
    private(set) var loginURLs: [AgentProvider: URL] = [:]

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

    func login(_ provider: AgentProvider) async {
        guard activity[provider] == nil else { return }
        activity[provider] = .signingIn
        loginURLs[provider] = nil
        defer {
            activity[provider] = nil
            loginURLs[provider] = nil
        }
        statuses[provider] = await service.login(provider: provider) { url in
            Task { @MainActor in self.loginURLs[provider] = url }
        }
    }

    /// Aborts an in-flight sign-in; the awaiting `login` call then finishes and refreshes status.
    func cancelLogin(_ provider: AgentProvider) {
        service.cancelLogin(provider: provider)
    }

    func logout(_ provider: AgentProvider) async {
        guard activity[provider] == nil else { return }
        activity[provider] = .signingOut
        defer { activity[provider] = nil }
        statuses[provider] = await service.logout(provider: provider)
    }
}

/// Settings is shown inline in the main window's detail area; the "‹ Back" affordance lives in the
/// navigation header (see `RootView`), so this view is just the tabbed content.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            AccountsSettingsView()
                .tabItem { Label("Accounts", systemImage: "person.crop.circle") }
        }
        .padding(WhaleTheme.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WhaleTheme.Color.background)
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
        ScrollView {
            VStack(alignment: .leading, spacing: WhaleTheme.Spacing.lg) {
                SettingsSection(title: "Appearance") {
                    VStack(alignment: .leading, spacing: WhaleTheme.Spacing.md) {
                        HStack {
                            Text("Theme")
                                .font(WhaleTheme.Typography.body())
                            Spacer()
                            Picker(selection: $appearanceRaw) {
                                ForEach(AppearancePreference.allCases) { pref in
                                    Label(pref.displayName, systemImage: pref.symbol).tag(pref.rawValue)
                                }
                            } label: {
                                EmptyView()
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .onChange(of: appearanceRaw) { _, newValue in
                                AppearancePreference(rawValue: newValue)?.apply()
                            }
                        }

                        Text("Deep Ocean adapts to light and dark. “System” follows your macOS appearance.")
                            .font(WhaleTheme.Typography.caption())
                            .foregroundStyle(WhaleTheme.Color.muted)
                    }
                }

                SettingsSection(title: "About") {
                    VStack(alignment: .leading, spacing: WhaleTheme.Spacing.sm) {
                        SettingsRow(label: "Version", value: appVersion)
                        SettingsRow(label: "Providers", value: "Claude · Codex · Cursor")
                    }
                }
            }
            .padding()
        }
        .background(WhaleTheme.Color.background)
    }
}

private struct AccountsSettingsView: View {
    @State private var viewModel = AccountsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WhaleTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: WhaleTheme.Spacing.sm) {
                    HStack {
                        Text("Accounts")
                            .font(WhaleTheme.Typography.body().bold())
                            .foregroundStyle(WhaleTheme.Color.text)
                        Spacer()
                        Button {
                            Task { await viewModel.refreshAll() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .help("Re-check login status")
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(AgentProvider.allCases) { provider in
                            AccountRow(
                                provider: provider,
                                status: viewModel.statuses[provider] ?? .unknown,
                                activity: viewModel.activity[provider],
                                loginURL: viewModel.loginURLs[provider],
                                onLogin: { Task { await viewModel.login(provider) } },
                                onLogout: { Task { await viewModel.logout(provider) } },
                                onCancel: { viewModel.cancelLogin(provider) }
                            )
                            if provider != AgentProvider.allCases.last {
                                Divider().overlay(WhaleTheme.Color.border)
                            }
                        }
                    }
                    .padding(WhaleTheme.Spacing.md)
                    .whaleSurface()

                    Text("Whale uses each provider's own CLI for sign-in. Login opens a Terminal window for the browser flow — return here and tap Refresh when done.")
                        .font(WhaleTheme.Typography.caption())
                        .foregroundStyle(WhaleTheme.Color.muted)
                        .padding(.horizontal, 2)
                }
            }
            .padding()
        }
        .background(WhaleTheme.Color.background)
        .task { await viewModel.refreshAll() }
    }
}

private struct AccountRow: View {
    let provider: AgentProvider
    let status: AccountStatus
    let activity: AccountsViewModel.Activity?
    let loginURL: URL?
    let onLogin: () -> Void
    let onLogout: () -> Void
    let onCancel: () -> Void

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

            trailing
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var statusLine: some View {
        switch activity {
        case .signingIn:
            Text("Complete sign-in in your browser…")
                .font(.caption)
                .foregroundStyle(WhaleTheme.Color.accent)
        case .signingOut:
            Text("Signing out…")
                .font(.caption)
                .foregroundStyle(.secondary)
        case nil:
            idleStatusLine
        }
    }

    @ViewBuilder
    private var idleStatusLine: some View {
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
    private var trailing: some View {
        switch activity {
        case .signingIn:
            HStack(spacing: WhaleTheme.Spacing.sm) {
                if let loginURL {
                    Button("Open Page") { NSWorkspace.shared.open(loginURL) }
                        .help(loginURL.absoluteString)
                }
                ProgressView().controlSize(.small)
                Button("Cancel", action: onCancel)
            }
        case .signingOut:
            ProgressView().controlSize(.small)
        case nil:
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
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WhaleTheme.Spacing.sm) {
            Text(title)
                .font(WhaleTheme.Typography.body().bold())
                .foregroundStyle(WhaleTheme.Color.text)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(WhaleTheme.Spacing.md)
            .whaleSurface()
        }
    }
}

private struct SettingsRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(WhaleTheme.Typography.body())
                .foregroundStyle(WhaleTheme.Color.text)
            Spacer()
            Text(value)
                .font(WhaleTheme.Typography.body())
                .foregroundStyle(WhaleTheme.Color.muted)
        }
    }
}

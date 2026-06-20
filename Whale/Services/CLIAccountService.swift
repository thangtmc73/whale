import Foundation
import AppKit

/// Login state for one provider's CLI, derived from that CLI's own `status` command — Whale never
/// stores credentials itself, it only reflects (and triggers) the CLI's native auth.
struct AccountStatus: Equatable {
    enum State: Equatable {
        case loggedIn
        case loggedOut
        case notInstalled
        case unknown
    }

    var state: State
    /// Email / auth method shown next to the status, when the CLI reports one.
    var detail: String?

    static let unknown = AccountStatus(state: .unknown, detail: nil)
}

extension AgentProvider {
    /// Arguments for `<cli> <status>` — each CLI exposes its own auth subcommand (verified against
    /// the installed binaries): `claude auth status` returns JSON, `codex login status` and
    /// `cursor-agent status` return a human line.
    var statusArguments: [String] {
        switch self {
        case .claude: return ["auth", "status"]
        case .codex: return ["login", "status"]
        case .cursor: return ["status"]
        }
    }

    var logoutArguments: [String] {
        switch self {
        case .claude: return ["auth", "logout"]
        case .codex: return ["logout"]
        case .cursor: return ["logout"]
        }
    }

    /// Shell command run in a real Terminal window — login is an interactive, browser-based flow,
    /// so it needs a TTY the user can see rather than a captured background subprocess.
    var loginShellCommand: String {
        switch self {
        case .claude: return "claude auth login"
        case .codex: return "codex login"
        case .cursor: return "cursor-agent login"
        }
    }
}

/// Runs each provider CLI's native auth commands. Status and logout are captured subprocesses;
/// login is delegated to Terminal because its browser handshake expects an interactive session.
final class CLIAccountService {
    func status(for provider: AgentProvider) async -> AccountStatus {
        guard let resolved = try? await ProcessPathResolver.shared.resolveFirst(of: provider.executableNames) else {
            return AccountStatus(state: .notInstalled, detail: nil)
        }
        guard let result = try? await run(executable: resolved.path, arguments: provider.statusArguments, environment: resolved.environment) else {
            return .unknown
        }
        return parseStatus(provider: provider, exitCode: result.exitCode, stdout: result.stdout)
    }

    /// Returns the refreshed status after logout so the caller can update its UI in one step.
    func logout(provider: AgentProvider) async -> AccountStatus {
        if let resolved = try? await ProcessPathResolver.shared.resolveFirst(of: provider.executableNames) {
            _ = try? await run(executable: resolved.path, arguments: provider.logoutArguments, environment: resolved.environment)
        }
        return await status(for: provider)
    }

    /// Opens Terminal and runs the provider's login command there. The user completes the browser
    /// flow, then returns to Whale and refreshes status manually (the CLI's callback server lives
    /// in that Terminal process, not in this app).
    func beginLogin(provider: AgentProvider) {
        let command = provider.loginShellCommand
        let script = """
        tell application "Terminal"
            activate
            do script "\(command)"
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }

    private func parseStatus(provider: AgentProvider, exitCode: Int32, stdout: String) -> AccountStatus {
        let trimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        switch provider {
        case .claude:
            // `claude auth status` emits JSON: {"loggedIn": true, "email": "...", ...}
            if let data = trimmed.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let loggedIn = json["loggedIn"] as? Bool ?? false
                let detail = json["email"] as? String ?? json["authMethod"] as? String
                return AccountStatus(state: loggedIn ? .loggedIn : .loggedOut, detail: loggedIn ? detail : nil)
            }
            return exitCode == 0 ? .unknown : AccountStatus(state: .loggedOut, detail: nil)
        case .codex, .cursor:
            // Human lines: "Logged in using ChatGPT" / "✓ Logged in as me@x.com" / "Not logged in".
            let lower = trimmed.lowercased()
            if lower.contains("not logged in") || lower.contains("logged out") {
                return AccountStatus(state: .loggedOut, detail: nil)
            }
            if lower.contains("logged in") {
                return AccountStatus(state: .loggedIn, detail: extractDetail(from: trimmed))
            }
            return .unknown
        }
    }

    /// Pulls the email/method out of a "Logged in as me@x.com" / "Logged in using ChatGPT" line.
    private func extractDetail(from line: String) -> String? {
        let cleaned = line.replacingOccurrences(of: "✓", with: "").trimmingCharacters(in: .whitespaces)
        for marker in [" as ", " using "] {
            if let range = cleaned.range(of: marker) {
                let detail = cleaned[range.upperBound...].trimmingCharacters(in: .whitespaces)
                return detail.isEmpty ? nil : detail
            }
        }
        return nil
    }

    private struct CommandResult {
        let exitCode: Int32
        let stdout: String
    }

    private func run(executable: String, arguments: [String], environment: [String: String]) async throws -> CommandResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.environment = environment

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = Pipe()

            process.terminationHandler = { proc in
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: CommandResult(exitCode: proc.terminationStatus, stdout: stdout))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

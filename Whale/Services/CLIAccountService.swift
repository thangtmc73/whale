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

    var loginArguments: [String] {
        switch self {
        case .claude: return ["auth", "login"]
        case .codex: return ["login"]
        case .cursor: return ["login"]
        }
    }

    var logoutArguments: [String] {
        switch self {
        case .claude: return ["auth", "logout"]
        case .codex: return ["logout"]
        case .cursor: return ["logout"]
        }
    }
}

/// Runs each provider CLI's native auth commands as managed in-app subprocesses.
///
/// Login is intentionally NOT delegated to an external Terminal: Codex hosts its OAuth callback
/// server on `localhost` *inside the login process*, and Cursor polls its backend from inside the
/// login process — so the flow only completes (and is observable) if that process stays alive as a
/// child of this app. An external Terminal detaches it: Cursor would finish without the app
/// noticing, and Codex's callback would land in a process the app can't see. Both CLIs run fine
/// without a TTY and open the browser themselves; `onURL` surfaces the link for a manual fallback.
final class CLIAccountService {
    private let lock = NSLock()
    private var loginProcesses: [AgentProvider: Process] = [:]

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

    /// Runs `<cli> login` and stays alive until the CLI exits (i.e. the browser flow completes or
    /// is abandoned), then resolves to the refreshed status. `onURL` fires with the sign-in link
    /// parsed from the CLI's output, so the UI can offer a manual "open page" fallback if the
    /// browser didn't open on its own.
    func login(provider: AgentProvider, onURL: @escaping (URL) -> Void) async -> AccountStatus {
        guard let resolved = try? await ProcessPathResolver.shared.resolveFirst(of: provider.executableNames) else {
            return AccountStatus(state: .notInstalled, detail: nil)
        }
        await runLogin(provider: provider, executable: resolved.path, environment: resolved.environment, onURL: onURL)
        return await status(for: provider)
    }

    /// Aborts an in-flight login (e.g. user tapped Cancel) — terminates the CLI process, which
    /// also tears down its localhost callback server / polling loop.
    func cancelLogin(provider: AgentProvider) {
        lock.lock()
        let process = loginProcesses[provider]
        lock.unlock()
        process?.terminate()
    }

    private func runLogin(provider: AgentProvider, executable: String, environment: [String: String], onURL: @escaping (URL) -> Void) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = provider.loginArguments
            process.environment = environment

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            var didFindURL = false
            let scan: (FileHandle) -> Void = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                if !didFindURL, let url = Self.firstURL(in: text) {
                    didFindURL = true
                    DispatchQueue.main.async { onURL(url) }
                }
            }
            outPipe.fileHandleForReading.readabilityHandler = scan
            errPipe.fileHandleForReading.readabilityHandler = scan

            process.terminationHandler = { [weak self] _ in
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                self?.lock.lock()
                self?.loginProcesses[provider] = nil
                self?.lock.unlock()
                continuation.resume()
            }

            // Replace any stale login still holding the callback port before starting a new one.
            lock.lock()
            loginProcesses[provider]?.terminate()
            loginProcesses[provider] = process
            lock.unlock()

            do {
                try process.run()
            } catch {
                lock.lock()
                loginProcesses[provider] = nil
                lock.unlock()
                continuation.resume()
            }
        }
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

    static func firstURL(in text: String) -> URL? {
        for token in text.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }) {
            guard token.hasPrefix("https://") else { continue }
            return URL(string: String(token))
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

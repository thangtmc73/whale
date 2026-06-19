import Foundation

enum ClaudeCLIServiceError: Error, CustomStringConvertible {
    case executableNotFound

    var description: String {
        switch self {
        case .executableNotFound:
            return "Claude CLI not found on PATH. Make sure `claude` is installed and on your shell PATH."
        }
    }
}

/// Wraps the `claude` CLI as a subprocess. Does not reimplement any agent behavior — just
/// launches the real CLI in --print/stream-json mode and maps its output to shared Steps.
final class ClaudeCLIService: AgentCLIService {
    let provider: AgentProvider = .claude
    private let runner = ProcessStreamRunner()

    /// Claude can pre-assign its own session id (`--session-id`), so unlike Cursor there's no
    /// setup step before the first turn — `onResolveCLISessionID` is called immediately with the
    /// id that was already passed in.
    func sendTurn(
        prompt: String,
        in projectPath: URL,
        session: Session,
        model: ModelOption,
        permissionMode: PermissionMode,
        onResolveCLISessionID: @escaping (String) -> Void
    ) -> AsyncThrowingStream<Step, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let resolved = try await ProcessPathResolver.shared.resolveFirst(of: AgentProvider.claude.executableNames) else {
                        continuation.finish(throwing: ClaudeCLIServiceError.executableNotFound)
                        return
                    }

                    onResolveCLISessionID(session.cliSessionID)

                    var arguments = [
                        "-p",
                        "--output-format", "stream-json",
                        "--include-partial-messages",
                        "--verbose",
                        "--model", model.id,
                    ]
                    if permissionMode == .autoAccept {
                        arguments += ["--permission-mode", "acceptEdits"]
                    }
                    arguments += session.hasBeenStarted ? ["--resume", session.cliSessionID] : ["--session-id", session.cliSessionID]
                    arguments.append(prompt)

                    let lineStream = runner.run(
                        executable: resolved.path,
                        arguments: arguments,
                        currentDirectory: projectPath,
                        environment: resolved.environment
                    )

                    for try await line in lineStream {
                        for step in ClaudeEventParser.parse(line: line) {
                            continuation.yield(step)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { [weak self] _ in
                task.cancel()
                self?.runner.cancel()
            }
        }
    }

    func cancelCurrentTurn() {
        runner.cancel()
    }
}

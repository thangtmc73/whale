import Foundation

enum CodexCLIServiceError: Error, CustomStringConvertible {
    case executableNotFound

    var description: String {
        switch self {
        case .executableNotFound:
            return "Codex CLI not found on PATH. Make sure `codex` is installed and on your shell PATH."
        }
    }
}

/// Wraps the `codex` CLI as a subprocess. Verified against codex-cli 0.141.0: Codex's
/// non-interactive entry point is the `exec` subcommand (not Claude's `-p`), and like Cursor it
/// can't be handed a session id up front — the server-assigned thread id only appears in the
/// `thread.started` event of the JSONL stream itself, so `onResolveCLISessionID` is called from
/// inside the stream loop rather than before launch. Continuing a session is `exec resume <id>`;
/// `-s/--sandbox` is only accepted on the first turn — `codex exec resume` rejects it outright
/// since the sandbox policy is fixed for the life of the thread.
final class CodexCLIService: AgentCLIService {
    let provider: AgentProvider = .codex
    private let runner = ProcessStreamRunner()

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
                    guard let resolved = try await ProcessPathResolver.shared.resolveFirst(of: AgentProvider.codex.executableNames) else {
                        continuation.finish(throwing: CodexCLIServiceError.executableNotFound)
                        return
                    }

                    var arguments = ["exec"]
                    if session.hasBeenStarted {
                        arguments += ["resume", session.cliSessionID]
                    }
                    arguments += ["--json", "--skip-git-repo-check"]
                    if !session.hasBeenStarted {
                        arguments += ["-s", permissionMode == .autoAccept ? "workspace-write" : "read-only"]
                    }
                    arguments += ["-m", model.id, prompt]

                    let lineStream = runner.run(
                        executable: resolved.path,
                        arguments: arguments,
                        currentDirectory: projectPath,
                        environment: resolved.environment
                    )

                    var didResolveSessionID = session.hasBeenStarted
                    for try await line in lineStream {
                        if !didResolveSessionID, let threadID = CodexEventParser.threadID(fromLine: line) {
                            didResolveSessionID = true
                            onResolveCLISessionID(threadID)
                        }
                        for step in CodexEventParser.parse(line: line) {
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

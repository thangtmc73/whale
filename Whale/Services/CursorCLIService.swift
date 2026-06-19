import Foundation

enum CursorCLIServiceError: Error, CustomStringConvertible {
    case executableNotFound
    case createChatFailed

    var description: String {
        switch self {
        case .executableNotFound:
            return "Cursor CLI not found on PATH. Make sure `cursor-agent` is installed and on your shell PATH."
        case .createChatFailed:
            return "Failed to create a new Cursor chat session."
        }
    }
}

/// Wraps the `cursor-agent` CLI as a subprocess. Unlike Claude, Cursor can't pre-assign a
/// session id up front — the first turn must call `create-chat` to obtain a real chat id from
/// Cursor's backend before any prompt can be sent, then every turn after (including that first
/// one) uses `--resume <chatId>`.
final class CursorCLIService: AgentCLIService {
    let provider: AgentProvider = .cursor
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
                    guard let resolved = try await ProcessPathResolver.shared.resolveFirst(of: AgentProvider.cursor.executableNames) else {
                        continuation.finish(throwing: CursorCLIServiceError.executableNotFound)
                        return
                    }

                    let chatID: String
                    if session.hasBeenStarted {
                        chatID = session.cliSessionID
                    } else {
                        chatID = try await createChat(executable: resolved.path, in: projectPath, environment: resolved.environment)
                    }
                    onResolveCLISessionID(chatID)

                    var arguments = [
                        "-p",
                        "--output-format", "stream-json",
                        "--trust",
                        "--model", model.id,
                        "--resume", chatID,
                    ]
                    if permissionMode == .autoAccept {
                        arguments.append("-f")
                    }
                    arguments.append(prompt)

                    let lineStream = runner.run(
                        executable: resolved.path,
                        arguments: arguments,
                        currentDirectory: projectPath,
                        environment: resolved.environment
                    )

                    for try await line in lineStream {
                        for step in CursorEventParser.parse(line: line) {
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

    private func createChat(executable: String, in projectPath: URL, environment: [String: String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["create-chat"]
        process.currentDirectoryURL = projectPath
        process.environment = environment

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        try process.run()
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0,
              let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty else {
            throw CursorCLIServiceError.createChatFailed
        }
        return output
    }
}

import Foundation

enum ProcessStreamError: Error, CustomStringConvertible {
    case launchFailed(Error)
    case nonZeroExit(code: Int32, stderr: String)

    var description: String {
        switch self {
        case .launchFailed(let error):
            return "Failed to launch process: \(error.localizedDescription)"
        case .nonZeroExit(let code, let stderr):
            return "Process exited with code \(code): \(stderr)"
        }
    }
}

/// Shared low-level Process + Pipe plumbing used by every provider's CLIService.
/// Yields one decoded stdout line at a time; line-buffering and the stdout-EOF /
/// process-termination race are both handled here so provider services don't have to.
final class ProcessStreamRunner {
    private let lock = NSLock()
    private var process: Process?

    func run(
        executable: String,
        arguments: [String],
        currentDirectory: URL,
        environment: [String: String]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.currentDirectoryURL = currentDirectory
            process.environment = environment

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            // All mutable state below is only ever touched on this serial queue, so the
            // readabilityHandler callbacks (which fire on background dispatch queues) and
            // the terminationHandler can race freely without a data race.
            let bufferQueue = DispatchQueue(label: "agentdeck.processstream.buffer")
            var decoder = JSONLineDecoder()
            var stderrData = Data()
            var stdoutClosed = false
            var exitStatus: Int32?

            func finishIfReady() {
                guard stdoutClosed, let exitStatus else { return }
                if let remaining = decoder.flush(), !remaining.isEmpty {
                    continuation.yield(remaining)
                }
                if exitStatus != 0 {
                    let stderrText = String(data: stderrData, encoding: .utf8) ?? ""
                    continuation.finish(throwing: ProcessStreamError.nonZeroExit(code: exitStatus, stderr: stderrText))
                } else {
                    continuation.finish()
                }
            }

            // terminationHandler can fire before all buffered stdout has been delivered to
            // the readabilityHandler (SIGCHLD races the pipe's last read), so we only finish
            // once BOTH "stdout hit EOF" and "process exited" have been observed.
            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                bufferQueue.async {
                    guard !data.isEmpty else {
                        stdoutClosed = true
                        finishIfReady()
                        return
                    }
                    for line in decoder.feed(data) {
                        continuation.yield(line)
                    }
                }
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                bufferQueue.async { stderrData.append(data) }
            }

            process.terminationHandler = { proc in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                bufferQueue.async {
                    exitStatus = proc.terminationStatus
                    finishIfReady()
                }
            }

            lock.lock()
            self.process = process
            lock.unlock()

            do {
                try process.run()
            } catch {
                continuation.finish(throwing: ProcessStreamError.launchFailed(error))
                return
            }

            continuation.onTermination = { [weak self] _ in
                self?.cancel()
            }
        }
    }

    /// SIGINT first so the CLI can flush its own transcript file cleanly; SIGKILL after a
    /// grace period if it hasn't exited (Process.terminate() only sends SIGTERM, not SIGKILL,
    /// so the fallback goes straight to the kill() syscall).
    func cancel(killGracePeriod: TimeInterval = 3) {
        lock.lock()
        let proc = process
        lock.unlock()
        guard let proc, proc.isRunning else { return }

        proc.interrupt()
        let pid = proc.processIdentifier
        DispatchQueue.global().asyncAfter(deadline: .now() + killGracePeriod) {
            if proc.isRunning {
                kill(pid, SIGKILL)
            }
        }
    }
}

import Foundation

/// GUI apps launched from Finder/Dock don't inherit the interactive shell PATH, so a bare
/// `Process` launch by executable name (e.g. "claude") fails even though the CLI is installed
/// (commonly under ~/.local/bin, which isn't on the default launchd PATH). Resolve absolute
/// paths once via a login+interactive shell and cache them.
///
/// Must be interactive (`-i`), not just login (`-l`): on this machine (and commonly for
/// oh-my-zsh users) PATH customizations like `~/.local/bin` live in `.zshrc`, which only gets
/// sourced for interactive shells, not `.zprofile`/`.zshenv`. Dropping `-i` to avoid shell
/// integration noise (see below) silently loses that PATH entry instead — confirmed by
/// reproducing the GUI app's clean-room launchd environment with `env -i ... zsh -l -c ...`.
///
/// But interactive zsh sessions commonly run shell integration (oh-my-zsh, iTerm2/Terminal.app)
/// that writes OSC escape sequences straight into stdout with no surrounding newline — e.g. a
/// real observed line was "]7;file://host/cwd/Users/x/.local/bin/claude" where the OSC7
/// cwd-reporting sequence got glued directly onto a `which claude` result line. So each result
/// line here is tagged with a unique marker, and parsing searches for that marker as a
/// *substring* (not `hasPrefix`) so a glued-on escape prefix can't hide the tag.
actor ProcessPathResolver {
    static let shared = ProcessPathResolver()

    private static let binPrefix = "__WHALE_BIN__"
    private static let pathPrefix = "__WHALE_PATH__"

    struct ResolvedEnvironment {
        let executablePaths: [String: String]
        let path: String
    }

    private var cached: ResolvedEnvironment?

    func resolve(executableNames: [String]) async throws -> ResolvedEnvironment {
        if let cached { return cached }

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        var script = ""
        for name in executableNames {
            script += "echo \"\(Self.binPrefix)\(name)=$(command -v \(name) 2>/dev/null)\"\n"
        }
        script += "echo \"\(Self.pathPrefix)$PATH\"\n"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-i", "-l", "-c", script]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        try process.run()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let output = String(data: data, encoding: .utf8) ?? ""
        var resolvedPath = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin"
        var executablePaths: [String: String] = [:]

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(rawLine)
            if let tagRange = line.range(of: Self.pathPrefix) {
                resolvedPath = String(line[tagRange.upperBound...])
            } else if let tagRange = line.range(of: Self.binPrefix) {
                let remainder = line[tagRange.upperBound...]
                guard let equalsIndex = remainder.firstIndex(of: "=") else { continue }
                let name = String(remainder[remainder.startIndex..<equalsIndex])
                let path = String(remainder[remainder.index(after: equalsIndex)...])
                if path.hasPrefix("/") {
                    executablePaths[name] = path
                }
            }
        }

        let result = ResolvedEnvironment(executablePaths: executablePaths, path: resolvedPath)
        cached = result
        return result
    }

    /// Resolves the first executable name in `names` that's found on PATH.
    func resolveFirst(of names: [String]) async throws -> (path: String, environment: [String: String])? {
        let resolved = try await resolve(executableNames: names)
        guard let name = names.first(where: { resolved.executablePaths[$0] != nil }),
              let path = resolved.executablePaths[name] else {
            return fallbackResolve(of: names)
        }
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = resolved.path
        return (path, env)
    }
    
    /// Fallback: check common installation locations directly
    private func fallbackResolve(of names: [String]) -> (path: String, environment: [String: String])? {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let commonPaths = [
            "\(homeDir)/.local/bin",
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/usr/bin",
        ]
        
        for name in names {
            for dir in commonPaths {
                let fullPath = "\(dir)/\(name)"
                if FileManager.default.isExecutableFile(atPath: fullPath) {
                    var env = ProcessInfo.processInfo.environment
                    env["PATH"] = commonPaths.joined(separator: ":")
                    return (fullPath, env)
                }
            }
        }
        
        return nil
    }
}

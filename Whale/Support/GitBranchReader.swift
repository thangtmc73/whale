import Foundation

/// Reads the current branch name directly from `.git/HEAD` rather than shelling out to `git`
/// — this is called on every project selection and a plain file read is cheap and dependency-free.
enum GitBranchReader {
    static func currentBranch(at projectPath: URL) -> String? {
        let headURL = projectPath.appendingPathComponent(".git/HEAD")
        guard let contents = try? String(contentsOf: headURL, encoding: .utf8) else { return nil }
        let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("ref: refs/heads/") {
            return String(trimmed.dropFirst("ref: refs/heads/".count))
        }

        // Detached HEAD: HEAD contains a raw commit hash instead of a symbolic ref.
        if trimmed.count == 40, trimmed.allSatisfy(\.isHexDigit) {
            return "detached @ \(trimmed.prefix(7))"
        }

        return nil
    }
}

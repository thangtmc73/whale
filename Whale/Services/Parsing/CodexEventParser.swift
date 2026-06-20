import Foundation

/// Maps one JSONL line of `codex exec --json` into the shared `Step` model. Verified against
/// real codex-cli 0.141.0 output (`thread.started`/`turn.started`/`item.started`/
/// `item.completed`/`turn.completed`/`turn.failed`) — this is a different event shape from
/// Claude/Cursor's `type: assistant/user/result` schema, not a variant of it.
///
/// Resilience-first: never throws. JSON parse failures or item types we don't model become
/// `.unknown(raw:)` rather than killing the line stream.
enum CodexEventParser {
    static func parse(line: String) -> [Step] {
        guard let json = decode(line) else {
            return line.isEmpty ? [] : [Step(kind: .unknown(raw: line))]
        }

        switch json["type"] as? String {
        case "thread.started", "turn.started", "turn.completed", "item.started":
            return []
        case "item.completed":
            return parseItem(json, raw: line)
        case "turn.failed":
            return [Step(kind: .error(failureMessage(json)))]
        case "error":
            // Observed to always precede a matching `turn.failed` with the same message —
            // acting on the terminal event avoids showing the same failure twice.
            return []
        default:
            return [Step(kind: .unknown(raw: line))]
        }
    }

    /// `thread.started` is the only place Codex reports its server-assigned thread/session id —
    /// unlike Claude there's no flag to pre-assign one before the first turn (see CodexCLIService).
    static func threadID(fromLine line: String) -> String? {
        guard let json = decode(line), json["type"] as? String == "thread.started" else { return nil }
        return json["thread_id"] as? String
    }

    private static func decode(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func parseItem(_ json: [String: Any], raw: String) -> [Step] {
        guard let item = json["item"] as? [String: Any] else { return [] }
        switch item["type"] as? String {
        case "agent_message":
            guard let text = item["text"] as? String else { return [] }
            return [Step(kind: .assistantText(text))]
        case "reasoning":
            guard let text = item["text"] as? String else { return [] }
            return [Step(kind: .thinking(text))]
        case "command_execution":
            let command = item["command"] as? String ?? ""
            let output = item["aggregated_output"] as? String
            let exitCode = (item["exit_code"] as? NSNumber)?.int32Value
            return [Step(kind: .bashCommand(command: command, output: output, exitCode: exitCode, isRunning: false))]
        case "file_change":
            return fileChangeSteps(item)
        case "error":
            // A soft warning attached to this turn (e.g. unknown model id, falling back to
            // default metadata) — not necessarily fatal on its own, `turn.failed` covers that.
            guard let message = item["message"] as? String else { return [] }
            return [Step(kind: .systemNotice(message))]
        default:
            return [Step(kind: .unknown(raw: raw))]
        }
    }

    /// Codex's `file_change` items only ever report `path` + `kind` (add/update/delete), never
    /// before/after content, so `revertStrategy` is always nil — there's no safe basis to revert
    /// to and the view hides Discard in that case.
    private static func fileChangeSteps(_ item: [String: Any]) -> [Step] {
        guard let changes = item["changes"] as? [[String: Any]] else { return [] }
        return changes.compactMap { change -> Step? in
            guard let path = change["path"] as? String else { return nil }
            let diff = FileDiff(path: path, oldText: nil, newText: nil, unifiedDiff: nil, revertStrategy: nil)
            return Step(kind: .fileEdit(diff))
        }
    }

    /// `turn.failed`'s `error.message` is often itself a JSON-encoded API error string (e.g.
    /// `{"type":"error","status":400,"error":{"message":"..."}}`) — unwrap it for display
    /// instead of showing the raw JSON blob to the user.
    private static func failureMessage(_ json: [String: Any]) -> String {
        guard let error = json["error"] as? [String: Any], let raw = error["message"] as? String else {
            return "Codex exited with an error."
        }
        return unwrappedAPIErrorMessage(from: raw) ?? raw
    }

    private static func unwrappedAPIErrorMessage(from raw: String) -> String? {
        guard let data = raw.data(using: .utf8),
              let outer = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let inner = outer["error"] as? [String: Any],
              let message = inner["message"] as? String else {
            return nil
        }
        return message
    }
}

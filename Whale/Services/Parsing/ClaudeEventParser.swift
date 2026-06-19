import Foundation

/// Maps one line of `claude -p --output-format stream-json --include-partial-messages --verbose`
/// output into the shared `Step` model. Schema verified against a real local run (not guessed):
/// top-level `type` is one of system / stream_event / assistant / user / rate_limit_event / result.
///
/// Resilience-first: never throws. JSON parse failures or types we don't model become
/// `.unknown(raw:)` rather than killing the line stream — the real CLI output already includes
/// plenty of housekeeping line types (token estimates, hook events, rate limit info) that aren't
/// timeline-worthy, and future CLI versions will add more we haven't seen yet.
enum ClaudeEventParser {
    /// A single raw line can expand into zero or more Steps (an assistant line's `content`
    /// array can carry several blocks: thinking + text + tool_use all in one line).
    static func parse(line: String) -> [Step] {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return line.isEmpty ? [] : [Step(kind: .unknown(raw: line))]
        }

        switch json["type"] as? String {
        case "assistant":
            return parseAssistant(json)
        case "user":
            return parseUser(json)
        case "result":
            return parseResult(json)
        // Recognized-but-not-timeline-worthy: housekeeping the user doesn't need to see.
        case "system", "stream_event", "rate_limit_event":
            return []
        default:
            return [Step(kind: .unknown(raw: line))]
        }
    }

    private static func parseAssistant(_ json: [String: Any]) -> [Step] {
        guard let message = json["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else {
            return []
        }
        return content.compactMap(stepKind(forContentBlock:)).map { Step(kind: $0) }
    }

    private static func stepKind(forContentBlock block: [String: Any]) -> StepKind? {
        switch block["type"] as? String {
        case "text":
            guard let text = block["text"] as? String else { return nil }
            return .assistantText(text)
        case "thinking":
            guard let thinking = block["thinking"] as? String else { return nil }
            return .thinking(thinking)
        case "tool_use":
            return toolUseStepKind(block)
        default:
            return nil
        }
    }

    private static func toolUseStepKind(_ block: [String: Any]) -> StepKind? {
        guard let name = block["name"] as? String,
              let callID = block["id"] as? String else { return nil }
        let input = block["input"] as? [String: Any] ?? [:]
        let inputJSON = prettyJSON(input)

        switch name {
        case "Bash":
            let command = input["command"] as? String ?? inputJSON
            return .bashCommand(command: command, output: nil, exitCode: nil, isRunning: true)
        case "Edit", "Write", "MultiEdit", "NotebookEdit":
            let path = input["file_path"] as? String ?? input["notebook_path"] as? String ?? "unknown file"
            let oldText = input["old_string"] as? String
            let diff = FileDiff(
                path: path,
                oldText: oldText,
                newText: (input["new_string"] as? String) ?? (input["content"] as? String),
                unifiedDiff: nil,
                // Only "Edit" reports old_string/new_string (a substring pair). Write/MultiEdit/
                // NotebookEdit don't report a "before" state at all, so oldText is nil for them
                // and revertStrategy stays nil — no safe way to undo, so Discard must be hidden.
                revertStrategy: oldText != nil ? .replaceSubstring : nil
            )
            return .fileEdit(diff)
        default:
            return .toolCall(name: name, inputJSON: inputJSON, callID: callID)
        }
    }

    private static func parseUser(_ json: [String: Any]) -> [Step] {
        guard let message = json["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else {
            return []
        }
        return content.compactMap { block -> Step? in
            guard block["type"] as? String == "tool_result",
                  let callID = block["tool_use_id"] as? String else { return nil }
            let isError = block["is_error"] as? Bool ?? false
            let output = toolResultText(block["content"])
            return Step(kind: .toolResult(forCallID: callID, output: output, isError: isError))
        }
    }

    private static func toolResultText(_ content: Any?) -> String {
        if let text = content as? String {
            return text
        }
        if let blocks = content as? [[String: Any]] {
            return blocks.compactMap { $0["text"] as? String }.joined(separator: "\n")
        }
        return ""
    }

    private static func parseResult(_ json: [String: Any]) -> [Step] {
        guard json["is_error"] as? Bool == true else { return [] }
        let message = json["result"] as? String ?? "Claude exited with an error."
        return [Step(kind: .error(message))]
    }

    private static func prettyJSON(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}

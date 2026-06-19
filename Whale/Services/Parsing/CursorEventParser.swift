import Foundation

/// Maps one line of `cursor-agent -p --output-format stream-json --trust [-f]` output into the
/// shared `Step` model. Schema verified against a real local run (not guessed): top-level `type`
/// is one of system / user / assistant / tool_call / result. Unlike Claude, Cursor doesn't tag
/// streamed deltas separately from final messages — `--stream-partial-output` was deliberately
/// left off so every `assistant` line is already a complete chunk (confirmed empirically: with
/// the flag on, the same text repeats progressively across multiple lines with no flag to tell
/// "partial" from "final" other than an inconsistently-present `model_call_id`).
///
/// Resilience-first: never throws. JSON parse failures or types we don't model become
/// `.unknown(raw:)` instead of killing the line stream.
enum CursorEventParser {
    static func parse(line: String) -> [Step] {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return line.isEmpty ? [] : [Step(kind: .unknown(raw: line))]
        }

        switch json["type"] as? String {
        case "assistant":
            return parseAssistant(json)
        case "tool_call":
            return parseToolCall(json)
        case "result":
            return parseResult(json)
        // Recognized-but-not-timeline-worthy: session init housekeeping, and Cursor echoing our
        // own prompt back (we already show it as the Turn header).
        case "system", "user":
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
        return content.compactMap { block -> Step? in
            guard block["type"] as? String == "text", let text = block["text"] as? String else { return nil }
            return Step(kind: .assistantText(text))
        }
    }

    /// `tool_call.tool_call` is a single-key dict keyed by "<name>ToolCall" (e.g. "shellToolCall",
    /// "readToolCall", "editToolCall") whose value holds `args` and (once completed) `result`.
    private static func parseToolCall(_ json: [String: Any]) -> [Step] {
        guard let callID = json["call_id"] as? String,
              let toolCallContainer = json["tool_call"] as? [String: Any],
              let toolKey = toolCallContainer.keys.first,
              let toolPayload = toolCallContainer[toolKey] as? [String: Any] else {
            return []
        }
        let toolName = toolKey.hasSuffix("ToolCall") ? String(toolKey.dropLast("ToolCall".count)) : toolKey

        switch json["subtype"] as? String {
        case "started":
            let args = toolPayload["args"] as? [String: Any] ?? [:]
            return [Step(kind: startedStepKind(toolKey: toolKey, toolName: toolName, callID: callID, args: args))]
        case "completed":
            guard let result = toolPayload["result"] as? [String: Any] else { return [] }
            return completedSteps(toolKey: toolKey, callID: callID, result: result)
        default:
            return []
        }
    }

    private static func startedStepKind(toolKey: String, toolName: String, callID: String, args: [String: Any]) -> StepKind {
        switch toolKey {
        case "shellToolCall":
            let command = args["command"] as? String ?? prettyJSON(args)
            return .bashCommand(command: command, output: nil, exitCode: nil, isRunning: true)
        case "editToolCall", "writeToolCall":
            let path = args["path"] as? String ?? "unknown file"
            let newText = args["streamContent"] as? String ?? args["content"] as? String
            return .fileEdit(FileDiff(path: path, oldText: nil, newText: newText, unifiedDiff: nil))
        default:
            return .toolCall(name: toolName, inputJSON: prettyJSON(args), callID: callID)
        }
    }

    private static func completedSteps(toolKey: String, callID: String, result: [String: Any]) -> [Step] {
        if let rejected = result["rejected"] as? [String: Any] {
            let reason = (rejected["reason"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            let command = rejected["command"] as? String ?? ""
            let message = reason ?? "Rejected: \(command)"
            return [Step(kind: .toolResult(forCallID: callID, output: message, isError: true))]
        }

        guard let success = result["success"] as? [String: Any] else {
            // Unrecognized result shape (e.g. a "failure" case never observed in practice) —
            // surface the raw payload rather than silently dropping it.
            return [Step(kind: .toolResult(forCallID: callID, output: prettyJSON(result), isError: true))]
        }

        switch toolKey {
        case "shellToolCall":
            let exitCode = success["exitCode"] as? Int
            let stdout = success["stdout"] as? String ?? ""
            let stderr = success["stderr"] as? String ?? ""
            let output = ([stdout, stderr].filter { !$0.isEmpty }).joined(separator: "\n")
            return [Step(kind: .toolResult(forCallID: callID, output: output, isError: (exitCode ?? 0) != 0))]

        case "editToolCall", "writeToolCall":
            // Now that the edit has completed we have the real unified diff — emit a refined
            // fileEdit Step with it rather than just a generic tool result.
            let path = success["path"] as? String ?? "unknown file"
            let oldText = success["beforeFullFileContent"] as? String
            let diff = FileDiff(
                path: path,
                oldText: oldText,
                newText: success["afterFullFileContent"] as? String,
                unifiedDiff: success["diffString"] as? String,
                // Cursor reports the complete before/after file content, unlike Claude's Edit
                // tool (which only gives a substring pair) — safe to overwrite the whole file.
                revertStrategy: oldText != nil ? .overwriteWholeFile : nil
            )
            return [Step(kind: .fileEdit(diff))]

        case "readToolCall":
            let content = success["content"] as? String ?? prettyJSON(success)
            return [Step(kind: .toolResult(forCallID: callID, output: content, isError: false))]

        default:
            return [Step(kind: .toolResult(forCallID: callID, output: prettyJSON(success), isError: false))]
        }
    }

    private static func parseResult(_ json: [String: Any]) -> [Step] {
        guard json["is_error"] as? Bool == true else { return [] }
        let message = json["result"] as? String ?? "Cursor exited with an error."
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

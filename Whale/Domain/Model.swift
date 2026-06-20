import Foundation

struct ModelOption: Identifiable, Hashable {
    /// Raw CLI value passed to --model, e.g. "sonnet", "opus", "gpt-5-codex".
    let id: String
    let displayName: String
    let provider: AgentProvider
}

enum ModelCatalog {
    static let claude: [ModelOption] = [
        ModelOption(id: "sonnet", displayName: "Sonnet", provider: .claude),
        ModelOption(id: "opus", displayName: "Opus", provider: .claude),
        ModelOption(id: "fable", displayName: "Fable", provider: .claude),
    ]

    /// Verified against the real `cursor-agent models` output for this account — the previous
    /// "gpt-5"/"sonnet-4" ids were guesses and don't exist (cursor-agent rejects unknown model
    /// ids with "Cannot use this model: <id>"). `claude-4.5-sonnet` is listed as "(current)" by
    /// cursor-agent itself, so it's used as the default here rather than `auto`.
    static let cursor: [ModelOption] = [
        ModelOption(id: "claude-4.5-sonnet", displayName: "Sonnet 4.5", provider: .cursor),
        ModelOption(id: "claude-4.5-sonnet-thinking", displayName: "Sonnet 4.5 Thinking", provider: .cursor),
        ModelOption(id: "gpt-5.1", displayName: "GPT-5.1", provider: .cursor),
        ModelOption(id: "auto", displayName: "Auto", provider: .cursor),
    ]

    /// Verified against this account's real `~/.codex/models_cache.json` (codex-cli 0.141.0) —
    /// the previous "gpt-5-codex" id was a guess and codex rejects it ("not supported when
    /// using Codex with a ChatGPT account"). Only `visibility: "list"` slugs are offered here;
    /// `codex-auto-review` is hidden and not a general chat model.
    static let codex: [ModelOption] = [
        ModelOption(id: "gpt-5.5", displayName: "GPT-5.5", provider: .codex),
        ModelOption(id: "gpt-5.4-mini", displayName: "GPT-5.4-Mini", provider: .codex),
    ]

    static func options(for provider: AgentProvider) -> [ModelOption] {
        switch provider {
        case .claude: return claude
        case .cursor: return cursor
        case .codex: return codex
        }
    }

    static func defaultOption(for provider: AgentProvider) -> ModelOption {
        options(for: provider)[0]
    }
}

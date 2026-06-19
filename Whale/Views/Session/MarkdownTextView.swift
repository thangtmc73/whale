import Foundation
import SwiftUI

/// Renders assistant text as Markdown. Fenced code blocks are split out and rendered via
/// `CopyableCodeBlock` (so CLI commands/snippets inside an answer are copyable), and the
/// remaining prose is rendered through `AttributedString(markdown:)` for inline styling
/// (bold/italic/links/inline code).
struct MarkdownTextView: View {
    let raw: String

    enum Segment: Equatable {
        case prose(String)
        case code(language: String?, text: String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(Self.parse(raw).enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .prose(let text):
                    proseBlock(text)
                case .code(let language, let text):
                    CopyableCodeBlock(text: text, language: language)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `Text(AttributedString(markdown:, options: .full))` parses block structure (headers,
    /// lists, paragraphs) into `PresentationIntent` metadata, but plain `Text` never consults
    /// that metadata — so every list item/heading/paragraph collapses into one unbroken run with
    /// no line breaks at all (confirmed empirically: a numbered list of review comments renders
    /// as a single run-on sentence). The fix is to do block splitting ourselves — one line per
    /// `Text` — and parse each line with `.inlineOnlyPreservingWhitespace`, which only handles
    /// inline styling (bold/italic/code spans/links) and leaves block markers (`#`, `-`, `1.`)
    /// as literal text instead of (incorrectly) trying to restructure a single line.
    @ViewBuilder
    private func proseBlock(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    Spacer().frame(height: 4)
                } else if let (level, content) = Self.headerInfo(line) {
                    Text(Self.attributed(from: content))
                        .font(Self.headerFont(level))
                        .foregroundStyle(WhaleTheme.Color.text)
                        .textSelection(.enabled)
                } else {
                    Text(Self.attributed(from: line))
                        .font(WhaleTheme.Typography.body(13))
                        .foregroundStyle(WhaleTheme.Color.text)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private static func attributed(from line: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: line, options: options)) ?? AttributedString(line)
    }

    /// `# `/`## `/etc. is block syntax, so inline-only parsing leaves it as literal text — detect
    /// and style it ourselves rather than showing the raw hashes.
    static func headerInfo(_ line: String) -> (level: Int, content: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }
        let level = trimmed.prefix { $0 == "#" }.count
        guard level <= 6, trimmed.count > level, trimmed[trimmed.index(trimmed.startIndex, offsetBy: level)] == " " else { return nil }
        return (level, String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces))
    }

    private static func headerFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title2.bold()
        case 2: return .title3.bold()
        default: return .headline
        }
    }

    /// Line-based scan matching CommonMark fence semantics: a closing fence must have at least
    /// as many backticks as its opening fence. A naive "first ``` to next ```" regex breaks as
    /// soon as the assistant's text embeds another markdown document's own raw content (that
    /// document's internal ``` fences get mistaken for the outer closing fence, leaking the
    /// rest of the embedded file into "prose" with stray backticks). Matching by fence length
    /// keeps an embedded document's own fences isolated from the outer message, as long as the
    /// outer fence uses more backticks than anything nested inside it (the standard way to quote
    /// code containing ``` is to wrap it in ```` or more).
    static func parse(_ raw: String) -> [Segment] {
        var segments: [Segment] = []
        var proseLines: [String] = []
        var codeLines: [String] = []
        var fenceLength = 0
        var fenceLanguage: String?
        var inCode = false

        func flushProse() {
            let text = proseLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { segments.append(.prose(text)) }
            proseLines = []
        }

        func flushCode() {
            segments.append(.code(language: fenceLanguage, text: codeLines.joined(separator: "\n")))
            codeLines = []
            fenceLanguage = nil
            fenceLength = 0
        }

        for line in raw.components(separatedBy: "\n") {
            if inCode {
                if let closeLength = closingFenceLength(line), closeLength >= fenceLength {
                    inCode = false
                    flushCode()
                } else {
                    codeLines.append(line)
                }
            } else if let (length, language) = openingFence(line), length >= 3 {
                flushProse()
                inCode = true
                fenceLength = length
                fenceLanguage = language
            } else {
                proseLines.append(line)
            }
        }

        // Unterminated fence: still surface what was captured as a code block rather than
        // losing it or leaking it into prose.
        if inCode {
            flushCode()
        } else {
            flushProse()
        }

        return segments.isEmpty ? [.prose(raw)] : segments
    }

    private static func openingFence(_ line: String) -> (length: Int, language: String?)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("```") else { return nil }
        let length = trimmed.prefix { $0 == "`" }.count
        let language = trimmed.dropFirst(length).trimmingCharacters(in: .whitespaces)
        return (length, language.isEmpty ? nil : language)
    }

    /// A closing fence line must contain *only* backticks (no language label) per CommonMark.
    private static func closingFenceLength(_ line: String) -> Int? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.allSatisfy({ $0 == "`" }) else { return nil }
        return trimmed.count
    }
}

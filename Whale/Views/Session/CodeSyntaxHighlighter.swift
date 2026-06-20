import Foundation
import SwiftUI

/// Lightweight, dependency-free syntax highlighting — a single regex pass over comments,
/// strings, numbers, and a curated keyword list per language. This is a heuristic, not a real
/// tokenizer/parser (no AST, no per-language grammar correctness), but it's "good enough" for
/// quickly scanning a code block in a chat timeline without pulling in a highlighting library.
enum CodeSyntaxHighlighter {
    private struct LanguageSpec {
        var lineComment: String?
        var blockComment: (open: String, close: String)?
        var keywords: Set<String>
    }

    private static let swiftKeywords: Set<String> = [
        "func", "var", "let", "if", "else", "guard", "return", "struct", "class", "enum", "case",
        "switch", "for", "while", "import", "private", "public", "internal", "fileprivate",
        "static", "init", "self", "Self", "extension", "protocol", "throws", "throw", "try",
        "catch", "async", "await", "nil", "true", "false", "in", "is", "as", "do", "defer",
        "where", "typealias", "mutating", "weak", "lazy", "associatedtype", "some",
    ]
    private static let jsKeywords: Set<String> = [
        "function", "var", "let", "const", "if", "else", "return", "class", "case", "switch",
        "for", "while", "import", "export", "default", "async", "await", "try", "catch", "throw",
        "new", "this", "typeof", "instanceof", "null", "undefined", "true", "false", "of", "in",
        "do", "extends", "super", "static", "yield",
    ]
    private static let tsExtraKeywords: Set<String> = [
        "interface", "type", "enum", "implements", "public", "private", "protected", "readonly",
        "namespace", "as", "is", "keyof", "abstract",
    ]
    private static let pythonKeywords: Set<String> = [
        "def", "class", "if", "elif", "else", "return", "import", "from", "as", "for", "while",
        "try", "except", "finally", "with", "lambda", "pass", "break", "continue", "yield", "is",
        "in", "not", "and", "or", "None", "True", "False", "self", "async", "await", "global",
        "nonlocal", "raise", "assert", "del",
    ]
    private static let shellKeywords: Set<String> = [
        "if", "then", "else", "elif", "fi", "for", "while", "do", "done", "case", "esac",
        "function", "return", "exit", "local", "export", "echo", "in", "set", "shift",
    ]
    private static let goKeywords: Set<String> = [
        "func", "var", "const", "if", "else", "return", "package", "import", "struct",
        "interface", "type", "for", "range", "switch", "case", "go", "chan", "select", "defer",
        "map", "nil", "true", "false", "break", "continue", "fallthrough",
    ]
    private static let rustKeywords: Set<String> = [
        "fn", "let", "mut", "if", "else", "match", "struct", "enum", "impl", "trait", "for",
        "while", "loop", "return", "use", "mod", "pub", "crate", "self", "Self", "true", "false",
        "async", "await", "move", "ref", "where", "dyn",
    ]
    private static let rubyKeywords: Set<String> = [
        "def", "end", "if", "elsif", "else", "unless", "class", "module", "return", "do", "while",
        "case", "when", "require", "require_relative", "yield", "nil", "true", "false", "self",
        "begin", "rescue", "ensure", "attr_accessor",
    ]
    private static let cFamilyKeywords: Set<String> = [
        "int", "char", "float", "double", "void", "if", "else", "for", "while", "return",
        "struct", "typedef", "static", "const", "switch", "case", "break", "continue", "sizeof",
        "long", "short", "unsigned", "signed", "enum", "union",
    ]
    private static let cppExtraKeywords: Set<String> = [
        "class", "public", "private", "protected", "namespace", "template", "new", "delete",
        "this", "virtual", "override", "auto", "nullptr", "using",
    ]
    private static let javaKeywords: Set<String> = [
        "public", "private", "protected", "class", "interface", "extends", "implements",
        "static", "final", "void", "return", "if", "else", "for", "while", "switch", "case",
        "new", "this", "super", "import", "package", "try", "catch", "finally", "throw",
        "throws", "null", "true", "false", "abstract",
    ]

    private static let specs: [String: LanguageSpec] = {
        var map: [String: LanguageSpec] = [:]
        func register(_ names: [String], lineComment: String?, blockComment: (String, String)?, keywords: Set<String>) {
            let spec = LanguageSpec(lineComment: lineComment, blockComment: blockComment, keywords: keywords)
            for name in names { map[name] = spec }
        }
        register(["swift"], lineComment: "//", blockComment: ("/*", "*/"), keywords: swiftKeywords)
        register(["javascript", "js", "jsx"], lineComment: "//", blockComment: ("/*", "*/"), keywords: jsKeywords)
        register(["typescript", "ts", "tsx"], lineComment: "//", blockComment: ("/*", "*/"), keywords: jsKeywords.union(tsExtraKeywords))
        register(["python", "py"], lineComment: "#", blockComment: nil, keywords: pythonKeywords)
        register(["bash", "sh", "shell", "zsh"], lineComment: "#", blockComment: nil, keywords: shellKeywords)
        register(["go", "golang"], lineComment: "//", blockComment: ("/*", "*/"), keywords: goKeywords)
        register(["rust", "rs"], lineComment: "//", blockComment: ("/*", "*/"), keywords: rustKeywords)
        register(["ruby", "rb"], lineComment: "#", blockComment: nil, keywords: rubyKeywords)
        register(["c"], lineComment: "//", blockComment: ("/*", "*/"), keywords: cFamilyKeywords)
        register(["cpp", "c++", "cc"], lineComment: "//", blockComment: ("/*", "*/"), keywords: cFamilyKeywords.union(cppExtraKeywords))
        register(["java", "kotlin", "kt"], lineComment: "//", blockComment: ("/*", "*/"), keywords: javaKeywords)
        register(["yaml", "yml"], lineComment: "#", blockComment: nil, keywords: [])
        register(["json"], lineComment: nil, blockComment: nil, keywords: [])
        return map
    }()

    static func highlight(_ text: String, language: String?) -> AttributedString {
        guard let language, let spec = specs[language.lowercased()], !text.isEmpty else {
            return AttributedString(text)
        }

        // Every named group is always declared in the compiled pattern (using a guaranteed-fail
        // `(?!)` placeholder when a language doesn't have that feature, e.g. Python has no block
        // comment) — `range(withName:)` below is only well-defined for names that actually exist
        // in the pattern, regardless of whether they ever match.
        let commentPart = spec.lineComment.map { "(?<comment>\(NSRegularExpression.escapedPattern(for: $0)).*$)" } ?? "(?<comment>(?!))"
        let blockCommentPart = spec.blockComment.map { bc in
            let open = NSRegularExpression.escapedPattern(for: bc.open)
            let close = NSRegularExpression.escapedPattern(for: bc.close)
            return "(?<blockComment>\(open)[\\s\\S]*?\(close))"
        } ?? "(?<blockComment>(?!))"
        let stringPart = "(?<string>\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'|`(?:\\\\.|[^`\\\\])*`)"
        let numberPart = "(?<number>\\b\\d+\\.?\\d*\\b)"
        let keywordPart: String
        if !spec.keywords.isEmpty {
            let escaped = spec.keywords.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
            keywordPart = "(?<keyword>\\b(?:\(escaped))\\b)"
        } else {
            keywordPart = "(?<keyword>(?!))"
        }
        let pattern = [commentPart, blockCommentPart, stringPart, numberPart, keywordPart].joined(separator: "|")

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
            return AttributedString(text)
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: nsRange)

        var result = AttributedString()
        var cursor = text.startIndex
        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            if cursor < range.lowerBound {
                result += AttributedString(String(text[cursor..<range.lowerBound]))
            }
            var styled = AttributedString(String(text[range]))
            if let color = color(for: match) {
                styled.foregroundColor = color
            }
            if match.range(withName: "keyword").location != NSNotFound {
                styled.font = WhaleTheme.Typography.mono().bold()
            }
            result += styled
            cursor = range.upperBound
        }
        if cursor < text.endIndex {
            result += AttributedString(String(text[cursor...]))
        }
        return result
    }

    private static func color(for match: NSTextCheckingResult) -> Color? {
        if match.range(withName: "comment").location != NSNotFound { return WhaleTheme.Code.muted }
        if match.range(withName: "blockComment").location != NSNotFound { return WhaleTheme.Code.muted }
        if match.range(withName: "string").location != NSNotFound { return WhaleTheme.Code.string }
        if match.range(withName: "number").location != NSNotFound { return WhaleTheme.Code.number }
        if match.range(withName: "keyword").location != NSNotFound { return WhaleTheme.Code.keyword }
        return nil
    }
}

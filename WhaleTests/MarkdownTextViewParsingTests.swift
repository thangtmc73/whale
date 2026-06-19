import XCTest
@testable import Whale

final class MarkdownTextViewParsingTests: XCTestCase {
    func testPlainProseNoFences() {
        let segments = MarkdownTextView.parse("just **bold** text")
        XCTAssertEqual(segments, [.prose("just **bold** text")])
    }

    func testSingleFencedCodeBlockWithLanguage() {
        let raw = "Run this:\n```bash\nls -la\n```\nDone."
        let segments = MarkdownTextView.parse(raw)
        XCTAssertEqual(segments, [
            .prose("Run this:"),
            .code(language: "bash", text: "ls -la"),
            .prose("Done."),
        ])
    }

    func testFenceWithNoLanguage() {
        let raw = "```\nplain code\n```"
        XCTAssertEqual(MarkdownTextView.parse(raw), [.code(language: nil, text: "plain code")])
    }

    /// The bug report: asking the assistant to display another markdown file's raw content
    /// breaks naive "first ``` to next ```" parsing because the embedded file's own fences get
    /// mistaken for the outer closing fence. A correctly nested quote uses a longer outer fence
    /// (here ```` four backticks) wrapping inner ``` fences — the parser must keep the whole
    /// embedded document as one isolated code block, not leak its tail into "prose".
    func testNestedFenceUsesLongerOuterDelimiter() {
        let raw = """
        Here is the file:
        ````markdown
        # Title

        ```swift
        let x = 1
        ```

        more text
        ````
        That's it.
        """
        let segments = MarkdownTextView.parse(raw)
        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[0], .prose("Here is the file:"))
        guard case .code(let language, let text) = segments[1] else {
            return XCTFail("expected a single isolated code segment for the embedded file")
        }
        XCTAssertEqual(language, "markdown")
        XCTAssertTrue(text.contains("```swift"))
        XCTAssertTrue(text.contains("more text"))
        XCTAssertEqual(segments[2], .prose("That's it."))
    }

    func testUnterminatedFenceStillSurfacesAsCode() {
        let raw = "```python\nprint('hi')"
        XCTAssertEqual(MarkdownTextView.parse(raw), [.code(language: "python", text: "print('hi')")])
    }

    func testMultipleSeparateFences() {
        let raw = "a\n```\none\n```\nb\n```\ntwo\n```\nc"
        XCTAssertEqual(MarkdownTextView.parse(raw), [
            .prose("a"),
            .code(language: nil, text: "one"),
            .prose("b"),
            .code(language: nil, text: "two"),
            .prose("c"),
        ])
    }

    func testHeaderInfoDetectsLevelAndStripsHashes() {
        let result = MarkdownTextView.headerInfo("## Review")
        XCTAssertEqual(result?.level, 2)
        XCTAssertEqual(result?.content, "Review")
    }

    func testHeaderInfoRequiresSpaceAfterHashes() {
        // "#foo" (no space) is not a header per CommonMark — must not be misdetected.
        XCTAssertNil(MarkdownTextView.headerInfo("#foo"))
    }

    func testHeaderInfoRejectsMoreThanSixHashes() {
        XCTAssertNil(MarkdownTextView.headerInfo("####### too many"))
    }

    func testHeaderInfoReturnsNilForNonHeaderLine() {
        XCTAssertNil(MarkdownTextView.headerInfo("- a bullet point"))
        XCTAssertNil(MarkdownTextView.headerInfo("plain text"))
    }
}

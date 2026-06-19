import XCTest
@testable import Whale

final class JSONLineDecoderTests: XCTestCase {
    func testSingleCompleteLine() {
        var decoder = JSONLineDecoder()
        let lines = decoder.feed(Data("{\"a\":1}\n".utf8))
        XCTAssertEqual(lines, ["{\"a\":1}"])
    }

    func testMultipleLinesInOneChunk() {
        var decoder = JSONLineDecoder()
        let lines = decoder.feed(Data("{\"a\":1}\n{\"b\":2}\n".utf8))
        XCTAssertEqual(lines, ["{\"a\":1}", "{\"b\":2}"])
    }

    func testLineSplitAcrossMultipleFeeds() {
        var decoder = JSONLineDecoder()
        var lines = decoder.feed(Data("{\"a\":".utf8))
        XCTAssertEqual(lines, [])
        lines = decoder.feed(Data("1}\n".utf8))
        XCTAssertEqual(lines, ["{\"a\":1}"])
    }

    func testByteSplitMidLineAcrossManyFeeds() {
        var decoder = JSONLineDecoder()
        let fullLine = "{\"text\":\"hello world\"}\n"
        var collected: [String] = []
        for byte in fullLine.utf8 {
            collected.append(contentsOf: decoder.feed(Data([byte])))
        }
        XCTAssertEqual(collected, ["{\"text\":\"hello world\"}"])
    }

    func testNoTrailingNewlineRequiresFlush() {
        var decoder = JSONLineDecoder()
        let lines = decoder.feed(Data("{\"a\":1}".utf8))
        XCTAssertEqual(lines, [])
        XCTAssertEqual(decoder.flush(), "{\"a\":1}")
        XCTAssertNil(decoder.flush())
    }

    func testEmptyFeedIsNoop() {
        var decoder = JSONLineDecoder()
        XCTAssertEqual(decoder.feed(Data()), [])
    }
}

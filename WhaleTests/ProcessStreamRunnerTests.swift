import XCTest
@testable import Whale

final class ProcessStreamRunnerTests: XCTestCase {
    func testStreamsLinesInOrder() async throws {
        let runner = ProcessStreamRunner()
        let stream = runner.run(
            executable: "/bin/sh",
            arguments: ["-c", "printf 'a\\nb\\nc\\n'"],
            currentDirectory: FileManager.default.temporaryDirectory,
            environment: [:]
        )

        var collected: [String] = []
        for try await line in stream {
            collected.append(line)
        }
        XCTAssertEqual(collected, ["a", "b", "c"])
    }

    func testFinalLineWithoutTrailingNewlineIsFlushed() async throws {
        let runner = ProcessStreamRunner()
        let stream = runner.run(
            executable: "/bin/sh",
            arguments: ["-c", "printf 'a\\nb'"],
            currentDirectory: FileManager.default.temporaryDirectory,
            environment: [:]
        )

        var collected: [String] = []
        for try await line in stream {
            collected.append(line)
        }
        XCTAssertEqual(collected, ["a", "b"])
    }

    func testNonZeroExitSurfacesStderr() async throws {
        let runner = ProcessStreamRunner()
        let stream = runner.run(
            executable: "/bin/sh",
            arguments: ["-c", "echo boom 1>&2; exit 7"],
            currentDirectory: FileManager.default.temporaryDirectory,
            environment: [:]
        )

        do {
            for try await _ in stream {}
            XCTFail("expected nonZeroExit error")
        } catch let ProcessStreamError.nonZeroExit(code, stderr) {
            XCTAssertEqual(code, 7)
            XCTAssertTrue(stderr.contains("boom"))
        }
    }

    func testCancelTerminatesLongRunningProcess() async throws {
        let runner = ProcessStreamRunner()
        let stream = runner.run(
            executable: "/bin/sh",
            arguments: ["-c", "trap 'exit 0' INT; sleep 30"],
            currentDirectory: FileManager.default.temporaryDirectory,
            environment: [:]
        )

        let task = Task {
            for try await _ in stream {}
        }

        try await Task.sleep(nanoseconds: 200_000_000)
        runner.cancel(killGracePeriod: 1)

        let result = await withTaskGroup(of: Bool.self) { group -> Bool in
            group.addTask {
                _ = try? await task.value
                return true
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }

        XCTAssertTrue(result, "process should have terminated within the timeout after cancel()")
    }
}

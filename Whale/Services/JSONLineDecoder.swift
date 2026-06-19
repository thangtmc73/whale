import Foundation

/// Buffers raw bytes across read callbacks and yields complete newline-delimited lines.
/// Partial lines (a write that lands mid-line) are held until the terminating "\n" arrives.
struct JSONLineDecoder {
    private var buffer: Data = Data()

    /// Feeds new bytes in, returning any complete lines now available.
    mutating func feed(_ data: Data) -> [String] {
        guard !data.isEmpty else { return [] }
        buffer.append(data)

        var lines: [String] = []
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[buffer.startIndex..<newlineIndex]
            if let line = String(data: lineData, encoding: .utf8) {
                lines.append(line)
            }
            buffer.removeSubrange(buffer.startIndex...newlineIndex)
        }
        return lines
    }

    /// Call when the stream ends, in case the final line wasn't newline-terminated.
    mutating func flush() -> String? {
        guard !buffer.isEmpty else { return nil }
        let remaining = String(data: buffer, encoding: .utf8)
        buffer.removeAll()
        return remaining
    }
}

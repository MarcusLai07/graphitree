import Foundation

/// Where Claude Code's session transcripts are and how to go through them quickly. Insights
/// (`SessionReader`) and the Usage page (`TranscriptStats`) both read them, for different things,
/// so the walk and the line scanning live here once.
///
/// Transcripts are JSONL and can run to hundreds of megabytes, mostly tool output. They're mapped
/// rather than read, lines are found with memchr, and the few lines that matter are picked out with
/// memmem before anything is decoded.
enum ClaudeTranscripts {
    static var claudeFolder: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude", isDirectory: true) }
    static var projectsFolder: URL { claudeFolder.appendingPathComponent("projects", isDirectory: true) }
    /// Claude Desktop's data folder. Its local-agent sessions keep Claude Code transcripts too.
    static var desktopFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Claude", isDirectory: true)
    }

    struct File {
        let url: URL
        let modified: Date
        let size: Int
    }

    /// Every `.jsonl` under `roots` changed at or after `since`. A file's modification date bounds
    /// its newest line, so older files can't hold anything newer and are left out.
    ///
    /// Under Claude Desktop's local-agent folder only the Claude Code transcripts count, which sit
    /// in each session's own `.claude/projects`.
    static func files(under roots: [URL], modifiedSince since: Date) -> [File] {
        var files: [File] = []
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        for root in roots {
            let isDesktop = root.lastPathComponent == "local-agent-mode-sessions"
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys) else { continue }
            for case let url as URL in enumerator where url.pathExtension == "jsonl" {
                if isDesktop, !url.path.contains("/.claude/projects/") { continue }
                guard let values = try? url.resourceValues(forKeys: Set(keys)),
                      let modified = values.contentModificationDate, modified >= since else { continue }
                files.append(File(url: url, modified: modified, size: values.fileSize ?? 0))
            }
        }
        return files
    }

    /// Calls `body` with each non-empty line's bytes (without its newline) until it returns false.
    /// The bytes are only valid during the call.
    static func forEachLine(of url: URL, _ body: (UnsafeRawPointer, Int) -> Bool) {
        autoreleasepool {
            guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return }
            forEachLine(of: data, body)
        }
    }

    /// The same, for lines already in memory, such as a decompressed log.
    static func forEachLine(of data: Data, _ body: (UnsafeRawPointer, Int) -> Bool) {
        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            guard let base = buffer.baseAddress else { return }
            var offset = 0
            while offset < buffer.count {
                let line = base + offset
                let remaining = buffer.count - offset
                let length = memchr(line, 0x0A, remaining).map { line.distance(to: UnsafeRawPointer($0)) } ?? remaining
                offset += length + 1
                guard length > 0 else { continue }
                if !body(line, length) { return }
            }
        }
    }

    /// Whether `needle` occurs in the `count` bytes at `bytes`.
    static func contains(_ bytes: UnsafeRawPointer, _ count: Int, _ needle: [UInt8]) -> Bool {
        needle.withUnsafeBytes { memmem(bytes, count, $0.baseAddress, $0.count) != nil }
    }

    static func contains(_ bytes: UnsafeRawPointer, _ count: Int, _ needle: String) -> Bool {
        contains(bytes, count, Array(needle.utf8))
    }
}

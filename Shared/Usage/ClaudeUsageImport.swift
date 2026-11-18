import Foundation

/// Brings Claude Usage's plan readings into Graphitree's own history, for someone moving over
/// from Claude Usage, the menu bar app the Usage page was ported from. Both write the same lines
/// (`UsageSample`), so the left-over-time charts and past cycles carry on as they were.
///
/// Claude Usage keeps them in its app group folder. Reading another app's folder makes macOS ask
/// once whether Graphitree may, and the read waits for the answer, so this runs off the main thread.
enum ClaudeUsageImport {
    static let groupSuffix = ".com.marcuslai.ClaudeUsage"
    static let fileNames = ["usage-history.old.jsonl", "usage-history.jsonl"]
    /// Set once an import has worked, to stop offering it.
    static let doneKey = "usage.importedClaudeUsage"

    enum Outcome: Equatable {
        case imported(added: Int, since: Date?)
        /// Claude Usage's folder had no readings.
        case nothingFound
        /// macOS didn't let Graphitree read it, or Graphitree couldn't write its own history.
        case failed(String)
    }

    /// Claude Usage's group folders on this Mac, the current team-prefixed one first, then the
    /// `group.` one it used before 0.6.1. Listing names doesn't open them, so it doesn't ask.
    static func folders(home: String) -> [URL] {
        let containers = URL(fileURLWithPath: home).appendingPathComponent("Library/Group Containers", isDirectory: true)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: containers.path)) ?? []
        return names.filter { $0.hasSuffix(groupSuffix) }
            .sorted { ($0.hasPrefix("group.") ? 1 : 0, $0) < ($1.hasPrefix("group.") ? 1 : 0, $1) }
            .map { containers.appendingPathComponent($0, isDirectory: true) }
    }

    static func isAvailable(home: String) -> Bool { !folders(home: home).isEmpty }

    /// The readings in history lines. Lines that don't decode are skipped.
    static func samples(in text: String) -> [UsageSample] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return text.split(separator: "\n").compactMap { try? decoder.decode(UsageSample.self, from: Data($0.utf8)) }
    }

    /// History lines for `samples`, as `UsageHistory` writes them.
    static func lines(_ samples: [UsageSample]) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return samples.compactMap { try? encoder.encode($0) }
            .map { String(decoding: $0, as: UTF8.self) + "\n" }
            .joined()
    }

    /// Every reading of both, once, oldest first. Both apps read every five minutes while they
    /// run, so an incoming reading within `overlap` of one Graphitree already has is the same
    /// moment read twice, and is left out.
    static func merge(existing: [UsageSample], incoming: [UsageSample], overlap: TimeInterval = 120) -> (samples: [UsageSample], added: Int) {
        let have = existing.map(\.ts).sorted()
        func near(_ date: Date) -> Bool {
            // The first reading at or after `date`, and the one before it.
            var low = 0, high = have.count
            while low < high {
                let mid = (low + high) / 2
                if have[mid] < date { low = mid + 1 } else { high = mid }
            }
            if low < have.count, have[low].timeIntervalSince(date) <= overlap { return true }
            if low > 0, date.timeIntervalSince(have[low - 1]) <= overlap { return true }
            return false
        }
        var seen = Set<Date>()
        let added = incoming.filter { !near($0.ts) && seen.insert($0.ts).inserted }
        let merged = (existing + added).sorted { $0.ts < $1.ts }
        return (merged, added.count)
    }

    /// Reads Claude Usage's history and adds it to Graphitree's.
    static func run(home: String) -> Outcome {
        var incoming: [UsageSample] = []
        var readAny = false
        for folder in folders(home: home) {
            for name in fileNames {
                guard let text = try? String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8) else { continue }
                readAny = true
                incoming += samples(in: text)
            }
        }
        guard readAny else { return .failed("macOS didn't let Graphitree read Claude Usage's folder, or it holds no history.") }
        guard !incoming.isEmpty else { return .nothingFound }
        guard let url = UsageHistory.fileURL else { return .failed("Graphitree has no history file.") }
        // Graphitree keeps appending a reading every five minutes meanwhile. Merging takes a
        // moment, so the file is checked again just before it's replaced, and merged again if a
        // reading arrived.
        for _ in 0..<3 {
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let merged = merge(existing: samples(in: text), incoming: incoming)
            guard ((try? String(contentsOf: url, encoding: .utf8)) ?? "") == text else { continue }
            do {
                try lines(merged.samples).write(to: url, atomically: true, encoding: .utf8)
            } catch {
                return .failed(error.localizedDescription)
            }
            return .imported(added: merged.added, since: merged.samples.first?.ts)
        }
        return .failed("Graphitree's history kept changing. Try again.")
    }
}

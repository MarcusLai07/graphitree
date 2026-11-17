import CoreServices
import Foundation

/// Watches a folder tree with FSEvents and reports changed paths, a few seconds at a time.
/// Paths come back under the root as given, even when it's reached through a symlink, such as
/// `/var` for `/private/var`.
final class FolderWatcher {
    private var stream: FSEventStreamRef?
    private let handler: ([String]) -> Void
    private let queue = DispatchQueue(label: "com.marcuslai.Graphitree.watcher", qos: .utility)

    init(root: String, latency: TimeInterval = 5, handler: @escaping ([String]) -> Void) {
        let given = root.hasSuffix("/") ? String(root.dropLast()) : root
        let real = given.withCString { pointer -> String in
            guard let resolved = realpath(pointer, nil) else { return given }
            defer { free(resolved) }
            return String(cString: resolved)
        }
        self.handler = real == given ? handler : { paths in
            handler(paths.map { $0.hasPrefix(real) ? given + $0.dropFirst(real.count) : $0 })
        }
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, count, paths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue()
            let list = unsafeBitCast(paths, to: NSArray.self) as? [String] ?? []
            watcher.handler(Array(list.prefix(count)))
        }
        stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            [root] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer)
        )
        if let stream {
            FSEventStreamSetDispatchQueue(stream, queue)
            FSEventStreamStart(stream)
        }
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit { stop() }
}

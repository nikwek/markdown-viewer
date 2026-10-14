import Foundation

/// Calls `onChange` when the file at `url` is modified, including when an editor
/// saves by writing a new file and renaming it over the original.
final class FileWatcher {
    private let url: URL
    private let onChange: @MainActor () -> Void
    private var source: DispatchSourceFileSystemObject?

    init(url: URL, onChange: @escaping @MainActor () -> Void) {
        self.url = url
        self.onChange = onChange
        start()
    }

    deinit {
        source?.cancel()
    }

    private func start() {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            // The file may be mid-replace; try again shortly.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.start() }
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .extend, .delete, .rename], queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            if !source.data.isDisjoint(with: [.delete, .rename]) {
                // The descriptor now points at the old inode; reattach to the path.
                source.cancel()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.start()
                    self?.fire()
                }
            } else {
                self.fire()
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        self.source = source
    }

    private func fire() {
        MainActor.assumeIsolated { onChange() }
    }
}

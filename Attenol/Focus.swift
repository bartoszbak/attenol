import AppKit

/// macOS has no public API for switching a Focus, so Do Not Disturb is switched by the
/// bundled "Attenol Focus" shortcut: run with any input it turns Do Not Disturb on, run
/// with none it turns it off.
@MainActor
final class Focus {
    private static let shortcutName = "Attenol Focus"
    private var pending: Task<Void, Never>?

    /// Requests run one after another, so the last one always decides the final state.
    @discardableResult
    func setDoNotDisturb(_ on: Bool) -> Task<Void, Never> {
        let previous = pending
        previous?.cancel()
        let task = Task {
            await previous?.value
            if on, await !Self.isInstalled() {
                await Self.install()
            }
            guard !Task.isCancelled else { return }
            await Self.shortcuts(["run", Self.shortcutName] + (on ? ["--input-path", Self.anyFile] : []))
        }
        pending = task
        return task
    }

    /// The file handed to the shortcut as its "on" input; only its presence matters.
    private static var anyFile: String {
        Bundle.main.bundleURL.appending(path: "Contents/Info.plist").path
    }

    private static func isInstalled() async -> Bool {
        let list = await shortcuts(["list"]) ?? ""
        return list.split(separator: "\n").contains { $0 == shortcutName }
    }

    /// Opens the bundled shortcut so Shortcuts offers to add it, then waits for the user
    /// to accept. Gives up when the request is cancelled by a newer one.
    private static func install() async {
        guard let file = Bundle.main.url(forResource: shortcutName, withExtension: "shortcut") else { return }
        NSWorkspace.shared.open(file)
        while !Task.isCancelled, await !isInstalled() {
            try? await Task.sleep(for: .seconds(2))
        }
    }

    /// Runs `/usr/bin/shortcuts` and returns what it printed, or nil if it failed.
    @discardableResult
    private nonisolated static func shortcuts(_ arguments: [String]) async -> String? {
        await Task.detached {
            let process = Process()
            let output = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = arguments
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
            } catch {
                return nil
            }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return process.terminationStatus == 0 ? String(decoding: data, as: UTF8.self) : nil
        }.value
    }
}

import AppKit

@MainActor
final class BlackDesktop {
    private var covers: [NSWindow] = []
    private var screenObserver: NSObjectProtocol?

    func show() {
        cover()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.cover() }
        }
    }

    func hide() {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil
        covers.forEach { $0.close() }
        covers = []
    }

    private func cover() {
        covers.forEach { $0.close() }
        covers = NSScreen.screens.map { screen in
            let cover = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            cover.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            cover.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            cover.backgroundColor = .black
            cover.hasShadow = false
            cover.hidesOnDeactivate = false
            cover.isReleasedWhenClosed = false
            cover.setFrame(screen.frame, display: false)
            cover.orderFrontRegardless()
            return cover
        }
    }
}

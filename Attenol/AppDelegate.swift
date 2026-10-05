import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let toggleItem = NSMenuItem(title: "", action: #selector(toggle), keyEquivalent: "")
    private let desktop = BlackDesktop()
    private let focus = Focus()
    private var isActive = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        toggleItem.target = self

        let menu = NSMenu()
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.menu = menu
        refresh()
    }

    // Quitting while started puts everything back first.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard isActive else { return .terminateNow }
        isActive = false
        desktop.hide()
        let restored = focus.setDoNotDisturb(false)
        Task {
            await restored.value
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    @objc private func toggle() {
        isActive.toggle()
        if isActive {
            desktop.show()
        } else {
            desktop.hide()
        }
        focus.setDoNotDisturb(isActive)
        refresh()
    }

    private func refresh() {
        toggleItem.title = isActive ? "Pause" : "Start"
        statusItem.button?.image = Self.icon(filled: isActive)
    }

    /// A filled disc when started, a ring when paused. Drawn by hand because SF Symbols
    /// has no ring this thick, at the same 13 pt diameter as `circle.fill`.
    private static func icon(filled: Bool) -> NSImage {
        let outline = 2.5
        let image = NSImage(size: NSSize(width: 15, height: 15), flipped: false) { bounds in
            let disc = bounds.insetBy(dx: 1, dy: 1)
            if filled {
                NSBezierPath(ovalIn: disc).fill()
            } else {
                let ring = NSBezierPath(ovalIn: disc.insetBy(dx: outline / 2, dy: outline / 2))
                ring.lineWidth = outline
                ring.stroke()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = filled ? "Attenol is on" : "Attenol is off"
        return image
    }
}

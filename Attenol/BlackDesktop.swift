import AppKit

enum HideMode: String, CaseIterable {
    case wallpaperAndIcons
    case icons
    case wallpaper

    private static let key = "hideMode"

    static var saved: HideMode {
        get { UserDefaults.standard.string(forKey: key).flatMap(HideMode.init) ?? .wallpaperAndIcons }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }

    var title: String {
        switch self {
        case .wallpaperAndIcons: "Hide Wallpaper and Icons"
        case .icons: "Hide Icons"
        case .wallpaper: "Hide Wallpaper"
        }
    }
}

@MainActor
final class BlackDesktop {
    var mode = HideMode.saved {
        didSet {
            guard mode != oldValue else { return }
            HideMode.saved = mode
            if isShown { cover() }
        }
    }

    private var covers: [NSWindow] = []
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var wallpaperTimer: Timer?
    private var isShown = false

    func show() {
        isShown = true
        cover()
        observe(NotificationCenter.default, NSApplication.didChangeScreenParametersNotification) { $0.cover() }
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.activeSpaceDidChangeNotification) { $0.paint() }
        wallpaperTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.paint() }
        }
    }

    func hide() {
        isShown = false
        observers.forEach { $0.removeObserver($1) }
        observers = []
        wallpaperTimer?.invalidate()
        wallpaperTimer = nil
        covers.forEach { $0.close() }
        covers = []
    }

    private func observe(
        _ center: NotificationCenter, _ name: Notification.Name, _ action: @escaping @MainActor (BlackDesktop) -> Void
    ) {
        let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                if let self { action(self) }
            }
        }
        observers.append((center, observer))
    }

    private var level: NSWindow.Level {
        let icons = Int(CGWindowLevelForKey(.desktopIconWindow))
        return NSWindow.Level(mode == .wallpaper ? icons - 1 : icons + 1)
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
            cover.level = level
            cover.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            cover.backgroundColor = .black
            cover.hasShadow = false
            cover.hidesOnDeactivate = false
            cover.isReleasedWhenClosed = false
            cover.ignoresMouseEvents = mode == .wallpaper
            cover.contentView?.wantsLayer = true
            cover.setFrame(screen.frame, display: false)
            return cover
        }
        paint()
        covers.forEach { $0.orderFrontRegardless() }
    }

    private func paint() {
        for cover in covers {
            guard let layer = cover.contentView?.layer else { continue }
            guard mode == .icons, let screen = cover.screen ?? NSScreen.main,
                let url = NSWorkspace.shared.desktopImageURL(for: screen),
                let image = NSImage(contentsOf: url)
            else {
                layer.contents = nil
                layer.backgroundColor = .black
                continue
            }
            let options = NSWorkspace.shared.desktopImageOptions(for: screen) ?? [:]
            let scaling = (options[.imageScaling] as? NSNumber)
                .flatMap { NSImageScaling(rawValue: $0.uintValue) } ?? .scaleProportionallyUpOrDown
            let clips = (options[.allowClipping] as? NSNumber)?.boolValue ?? true
            switch scaling {
            case .scaleAxesIndependently: layer.contentsGravity = .resize
            case .scaleNone: layer.contentsGravity = .center
            default: layer.contentsGravity = clips ? .resizeAspectFill : .resizeAspect
            }
            layer.masksToBounds = true
            layer.contentsScale = screen.backingScaleFactor
            layer.backgroundColor = ((options[.fillColor] as? NSColor) ?? .black).cgColor
            layer.contents = image
        }
    }
}

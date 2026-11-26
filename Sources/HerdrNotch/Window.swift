import AppKit
import SwiftUI

// The borderless window that carries the notch, and the pointer tracking that opens and closes it.

// MARK: - Window

/// Where the pointer counts, in screen points. The ears sit over the menu bar, so they never take it:
/// only the hardware notch opens the panel, the ears fold away while the pointer is over them, and
/// the menu bar beside the notch keeps its clicks while the panel is open.
struct Zones {
    let screen: NSRect
    let geo: Geometry

    func top(_ w: CGFloat, _ h: CGFloat) -> NSRect { NSRect(x: screen.midX - w / 2, y: screen.maxY - h, width: w, height: h) }
    var notch: NSRect { top(geo.notchWidth, geo.notchHeight) }
    /// The column between the notch and the floating panel, so the pointer can travel down into it.
    var bridge: NSRect { top(geo.notchWidth, geo.detach) }
    func peeking(_ m: NSPoint, ear: CGFloat) -> Bool { top(geo.closedWidth(ear: ear), geo.notchHeight).contains(m) && !notch.contains(m) }
    /// The open panel, which floats below the menu bar.
    func panel(width: CGFloat, height: CGFloat) -> NSRect {
        NSRect(x: screen.midX - width / 2, y: screen.maxY - geo.detach - height, width: width, height: height)
    }
}

final class Panel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = Store()
    var panel: Panel!
    var geo = Geometry(notchWidth: 190, notchHeight: 32)
    var screen: NSScreen!
    var windowLarge = false
    var leftAt: Date?          // when the pointer left the open panel
    var enteredAt: Date?       // when the pointer entered the closed notch
    var closedAt: Date?        // when the panel started closing
    var armed = true           // false after a click-through, until the pointer leaves the notch
    let pinned = ProcessInfo.processInfo.environment["HERDR_NOTCH_OPEN"] != nil   // testing: stay open

    func applicationDidFinishLaunching(_ n: Notification) {
        layoutForScreen()
        panel = Panel(contentRect: smallFrame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.contentView = NSHostingView(rootView: RootView(store: store, geo: geo))
        panel.orderFrontRegardless()
        store.start()
        if pinned { open() }
        let t = Timer(timeInterval: 1.0 / 40, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.layoutForScreen()
            self.panel.contentView = NSHostingView(rootView: RootView(store: self.store, geo: self.geo))
            self.panel.setFrame(self.windowLarge ? self.largeFrame : self.smallFrame, display: true)
        }
    }

    func layoutForScreen() {
        screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
        let top = screen.safeAreaInsets.top
        if top > 0, let l = screen.auxiliaryTopLeftArea, let r = screen.auxiliaryTopRightArea {
            geo = Geometry(notchWidth: screen.frame.width - l.width - r.width, notchHeight: top)
        } else {
            geo = Geometry(notchWidth: 150, notchHeight: max(24, screen.frame.maxY - screen.visibleFrame.maxY))
        }
    }

    func topRect(width: CGFloat, height: CGFloat) -> NSRect {
        NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - height, width: width, height: height)
    }
    /// The window while closed: just the notch and its two counters.
    var smallFrame: NSRect {
        topRect(width: geo.closedWidth(ear: Geometry.wideEar) + 16, height: geo.notchHeight + Geometry.announceHeight + 10)
    }
    /// The window while open: the panel, a detail card's width on each side so the panel stays centred, and shadow room.
    var largeFrame: NSRect {
        topRect(width: Geometry.traceWidth + 2 * (Geometry.cardGap + Geometry.cardWidth + Geometry.margin),
                height: geo.detach + Geometry.maxPanelHeight + Geometry.margin)
    }
    /// Where the detail card sits, including the gap back to the panel so the pointer can cross it.
    var cardRect: NSRect {
        NSRect(x: screen.frame.midX + store.panelWidth / 2, y: screen.frame.maxY - geo.detach - store.cardHeight,
               width: Geometry.cardGap + Geometry.cardWidth, height: store.cardHeight)
    }

    func open() {
        closedAt = nil; leftAt = nil
        store.announcement = nil
        windowLarge = true
        panel.setFrame(largeFrame, display: true)
        panel.ignoresMouseEvents = false
        store.poll()
        DispatchQueue.main.async { self.store.expanded = true }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    func tick() {
        let m = NSEvent.mouseLocation
        let z = Zones(screen: screen.frame, geo: geo)
        let notch = z.notch

        if store.expanded {
            if pinned { return }
            let body = z.panel(width: store.panelWidth, height: store.panelHeight(geo))
            let onCard = store.hoveredID != nil && cardRect.insetBy(dx: -6, dy: -10).contains(m)
            let inside = body.insetBy(dx: -14, dy: -8).contains(m) || z.bridge.contains(m) || onCard
            // Clicks outside the drawn shapes go to whatever is underneath, including the menu bar beside the notch.
            panel.ignoresMouseEvents = !(body.contains(m) || z.bridge.contains(m) || onCard)
            if inside || NSEvent.pressedMouseButtons != 0 { leftAt = nil; return }
            if leftAt == nil { leftAt = Date() }
            if Date().timeIntervalSince(leftAt!) > 0.28 { leftAt = nil; store.expanded = false }
            return
        }

        if windowLarge {                       // closing: let the animation finish, then give the screen back
            if closedAt == nil {
                closedAt = Date(); panel.ignoresMouseEvents = true; armed = !notch.contains(m)
                store.clearHover()
                store.markLooked()
            }
            if Date().timeIntervalSince(closedAt!) > 0.45 {
                windowLarge = false; closedAt = nil
                panel.setFrame(smallFrame, display: true)
            }
        }

        let peek = z.peeking(m, ear: store.hasEars ? store.earWidth : 0)
        if store.peek != peek { store.peek = peek }

        if !notch.contains(m) { armed = true; enteredAt = nil; return }
        guard armed, NSEvent.pressedMouseButtons == 0 else { return }
        if enteredAt == nil { enteredAt = Date() }
        if Date().timeIntervalSince(enteredAt!) > 0.07 { enteredAt = nil; open() }   // a short dwell, so passing over doesn't open it
    }
}

import AppKit

// Fork: a small pill just under the notch, so you can see the app is running and click it to open the panel.
// The notch itself is the camera cutout (nothing drawn there shows), so the pill hangs below the menu bar,
// inside the notch's width: it can't cover app menus, menu bar icons or the "<<" overflow button.

enum Chin {
    static let pill = CGSize(width: 28, height: 5)
    static let gap: CGFloat = 2                          // menu bar bottom to pill top
    static let pad: CGFloat = 2                          // a little extra to click on, around the pill
    static let fill = NSColor(calibratedRed: 0.165, green: 0.165, blue: 0.18, alpha: 1)
    static let rim = NSColor(white: 1, alpha: 0.35)
    static let waiting = NSColor(calibratedRed: 0.93, green: 0.62, blue: 0.59, alpha: 1)   // AgentState.blocked

    /// The pill's window, which is also the only place it takes clicks. Nil on a screen with no notch.
    static func rect(screen: NSRect, geo: Geometry, hasNotch: Bool) -> NSRect? {
        guard hasNotch else { return nil }
        let w = pill.width + 2 * pad, h = pill.height + gap + pad
        return NSRect(x: screen.midX - w / 2, y: screen.maxY - geo.notchHeight - h, width: w, height: h)
    }

    /// True while the menu bar is hidden on this display: the "always hide" setting, or a window covering the
    /// whole display, menu bar row included, which only a full-screen app or full-screen video does.
    /// `windows` is CGWindowListCopyWindowInfo output (bounds and layer only; no titles, no pixels), and
    /// `display` the display's bounds in the same top-left coordinates.
    static func menuBarHidden(windows: [[String: Any]], display: CGRect, alwaysHide: Bool) -> Bool {
        if alwaysHide { return true }
        return windows.contains { w in
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  let b = w[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = b["X"], let y = b["Y"], let width = b["Width"], let height = b["Height"] else { return false }
            return CGRect(x: x, y: y, width: width, height: height).contains(display)
        }
    }
}

/// Draws the pill and opens the panel on a click.
final class ChinView: NSView {
    var waiting = false { didSet { if waiting != oldValue { needsDisplay = true } } }
    var onClick: () -> Void = {}

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onClick() }

    override func draw(_ dirty: NSRect) {
        let r = NSRect(x: Chin.pad, y: bounds.height - Chin.gap - Chin.pill.height,
                       width: Chin.pill.width, height: Chin.pill.height)
        let p = NSBezierPath(roundedRect: r.insetBy(dx: 0.5, dy: 0.5), xRadius: 2.5, yRadius: 2.5)
        (waiting ? Chin.waiting : Chin.fill).setFill()
        p.fill()
        Chin.rim.setStroke()
        p.lineWidth = 1
        p.stroke()
    }
}

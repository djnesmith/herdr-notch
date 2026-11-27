import AppKit

// Fork: a small mark flush against the notch's left edge, in the menu bar row, like upstream's left ear
// trimmed to one dot. It shows the app is running and opens the panel on a click. Nothing is drawn right
// of the notch, where the status icons and the "<<" overflow button live.

enum LeftMark {
    static let width: CGFloat = 32
    static let dot: CGFloat = 8
    static let inset: CGFloat = 6                         // notch edge to the dot
    static let blocked = NSColor(calibratedRed: 0.93, green: 0.62, blue: 0.59, alpha: 1)   // AgentState colors
    static let working = NSColor(calibratedRed: 0.85, green: 0.74, blue: 0.47, alpha: 1)
    static let idle = NSColor(white: 1, alpha: 0.35)

    /// The mark's window, the only place it takes clicks. Nil on a screen with no notch.
    static func rect(screen: NSRect, geo: Geometry, hasNotch: Bool) -> NSRect? {
        guard hasNotch else { return nil }
        let notchLeft = screen.midX - geo.notchWidth / 2
        return NSRect(x: notchLeft - width, y: screen.maxY - geo.notchHeight, width: width, height: geo.notchHeight)
    }

    /// What the mark shows: red and the number waiting while any agent is blocked, amber while any works,
    /// dim otherwise.
    static func look(_ counts: [AgentState: Int]) -> (color: NSColor, count: String) {
        if let n = counts[.blocked], n > 0 { return (blocked, "\(n)") }
        if (counts[.working] ?? 0) > 0 { return (working, "") }
        return (idle, "")
    }

    /// True while the menu bar is hidden on this display: the "always hide the menu bar" setting, or a window
    /// covering the whole display, menu bar row included, which only full-screen apps and video do.
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

/// Draws the mark, right-aligned against the notch, and opens the panel on a click.
final class LeftMarkView: NSView {
    var look: (color: NSColor, count: String) = (LeftMark.idle, "") { didSet { needsDisplay = true } }
    var onClick: () -> Void = {}

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onClick() }

    override func draw(_ dirty: NSRect) {
        let d = LeftMark.dot
        let dotX = bounds.maxX - LeftMark.inset - d
        look.color.setFill()
        NSBezierPath(ovalIn: NSRect(x: dotX, y: bounds.midY - d / 2, width: d, height: d)).fill()
        guard !look.count.isEmpty else { return }
        let text = NSAttributedString(string: look.count, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor(white: 1, alpha: 0.95)])
        let s = text.size()
        text.draw(at: NSPoint(x: max(0, dotX - 4 - s.width), y: bounds.midY - s.height / 2))
    }
}

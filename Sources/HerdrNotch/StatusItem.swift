import AppKit
import Combine

// Fork: a normal menu bar icon, so you can see the app is running and click to open the panel.
// The system places status items, so it never covers app menus, other icons or the "<<" overflow.

/// What the panel does when it was opened by a click on the icon rather than by resting on the notch.
/// The pointer starts far from the panel, so the hover rule (close soon after the pointer leaves) waits
/// until the pointer has been in the panel once. Before that, a new click elsewhere closes it.
enum ClickOpen {
    enum Next: Equatable { case stay, close, hover }

    static func next(inside: Bool, onIcon: Bool, pressed: Bool, wasPressed: Bool) -> Next {
        if inside { return .hover }                         // reached the panel: the usual hover rules from here
        if onIcon { return .stay }                          // a click on the icon toggles it through its action
        return pressed && !wasPressed ? .close : .stay
    }

    /// The count beside the icon: agents waiting on you, or nothing.
    static func badge(_ counts: [AgentState: Int]) -> String {
        let n = counts[.blocked] ?? 0
        return n > 0 ? "\(n)" : ""
    }
}

final class StatusIcon {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var sub: AnyCancellable?

    init(store: Store, target: AnyObject, action: Selector) {
        item.autosaveName = "herdr-notch"
        guard let b = item.button else { return }
        b.image = StatusIcon.image
        b.imagePosition = .imageLeading
        b.toolTip = "Herdr Notch"
        b.target = target
        b.action = action
        sub = store.$counts.receive(on: RunLoop.main).sink { [weak b] c in
            b?.title = ClickOpen.badge(c)
        }
    }

    /// The icon's place on screen, so a click on it isn't read as a click elsewhere.
    var frame: NSRect { item.button?.window?.frame ?? .zero }

    /// A menu bar with a notch hanging from its middle; a template image, so it follows the menu bar's color.
    static let image: NSImage = {
        let img = NSImage(size: NSSize(width: 18, height: 14), flipped: false) { _ in
            let bar = NSBezierPath(roundedRect: NSRect(x: 1, y: 2, width: 16, height: 10), xRadius: 2.5, yRadius: 2.5)
            bar.lineWidth = 1.4
            NSColor.black.setStroke()
            bar.stroke()
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: 5.5, y: 7, width: 7, height: 5), xRadius: 1.5, yRadius: 1.5).fill()
            return true
        }
        img.isTemplate = true
        img.accessibilityDescription = "Herdr Notch"
        return img
    }()
}

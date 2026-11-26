import AppKit
import XCTest
@testable import HerdrNotch

// A made-up 1000 x 800 screen with a 200 x 30 notch: the notch spans x 400...600, the menu bar y 770...800.
final class ZonesTests: XCTestCase {
    let z = Zones(screen: NSRect(x: 0, y: 0, width: 1000, height: 800), geo: Geometry(notchWidth: 200, notchHeight: 30))

    func testOnlyTheHardwareNotchOpens() {
        XCTAssertTrue(z.notch.contains(NSPoint(x: 500, y: 785)))
        XCTAssertFalse(z.notch.contains(NSPoint(x: 380, y: 785)))       // in the left ear
        XCTAssertFalse(z.notch.contains(NSPoint(x: 500, y: 760)))       // below the menu bar
    }

    func testEarsFoldWhileThePointerIsOverThem() {
        XCTAssertTrue(z.peeking(NSPoint(x: 380, y: 785), ear: 58))
        XCTAssertTrue(z.peeking(NSPoint(x: 650, y: 785), ear: 58))
        XCTAssertFalse(z.peeking(NSPoint(x: 500, y: 785), ear: 58))     // the notch itself
        XCTAssertFalse(z.peeking(NSPoint(x: 300, y: 785), ear: 58))     // past the ear
        XCTAssertFalse(z.peeking(NSPoint(x: 380, y: 785), ear: 0))      // no ears drawn
    }

    func testOpenPanelLeavesTheMenuBarBesideTheNotch() {
        let body = z.panel(width: 720, height: 300)
        XCTAssertEqual(body.maxY, 800 - 38)                             // starts below the menu bar (detach = 30 + 8)
        let besideNotch = NSPoint(x: 360, y: 785)                       // a menu bar item next to the notch, within the panel's width
        XCTAssertFalse(body.contains(besideNotch))
        XCTAssertFalse(z.bridge.contains(besideNotch))
        XCTAssertFalse(body.insetBy(dx: -14, dy: -8).contains(besideNotch))
        XCTAssertTrue(z.bridge.contains(NSPoint(x: 500, y: 765)))       // the way down from the notch into the panel
        XCTAssertTrue(body.contains(NSPoint(x: 200, y: 700)))
    }
}

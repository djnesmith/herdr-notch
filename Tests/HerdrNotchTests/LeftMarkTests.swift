import AppKit
import XCTest
@testable import HerdrNotch

// The same made-up 1000 x 800 screen with a 200 x 30 notch as ZonesTests: the notch spans x 400...600.
final class LeftMarkTests: XCTestCase {
    let screen = NSRect(x: 0, y: 0, width: 1000, height: 800)
    let geo = Geometry(notchWidth: 200, notchHeight: 30)
    var leftOfNotch: NSRect { NSRect(x: 0, y: 770, width: 400, height: 30) }     // auxiliaryTopLeftArea
    var rightOfNotch: NSRect { NSRect(x: 600, y: 770, width: 400, height: 30) }  // auxiliaryTopRightArea: icons and "<<"

    func testMarkHugsTheNotchsLeftEdgeAndNeverTheRight() {
        let r = LeftMark.rect(screen: screen, geo: geo, hasNotch: true)!
        XCTAssertTrue(leftOfNotch.contains(r))
        XCTAssertEqual(r.maxX, 400)                                   // flush against the notch
        XCTAssertFalse(r.intersects(rightOfNotch))
        XCTAssertFalse(r.intersects(NSRect(x: 0, y: 0, width: 1000, height: 770)))   // nothing below the menu bar
        XCTAssertLessThanOrEqual(r.width, 36)
    }

    func testNothingOnAScreenWithoutANotch() {
        XCTAssertNil(LeftMark.rect(screen: screen, geo: geo, hasNotch: false))
    }

    func testColorAndCountFollowTheAgents() {
        XCTAssertEqual(LeftMark.look([.blocked: 2, .working: 3]).color, LeftMark.blocked)
        XCTAssertEqual(LeftMark.look([.blocked: 2, .working: 3]).count, "2")
        XCTAssertEqual(LeftMark.look([.working: 3, .done: 1]).color, LeftMark.working)
        XCTAssertEqual(LeftMark.look([.working: 3]).count, "")
        XCTAssertEqual(LeftMark.look([.done: 4, .idle: 2]).color, LeftMark.idle)
        XCTAssertEqual(LeftMark.look([:]).color, LeftMark.idle)
    }

    private func win(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, layer: Int = 0) -> [String: Any] {
        [kCGWindowLayer as String: layer, kCGWindowBounds as String: ["X": x, "Y": y, "Width": w, "Height": h]]
    }

    func testHiddenOnlyWhenAWindowCoversTheWholeDisplay() {
        let display = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let zoomed = win(0, 30, 1000, 770)                 // a maximized window stops below the menu bar
        let menuBarItself = win(0, 0, 1000, 31, layer: 24)
        XCTAssertFalse(LeftMark.menuBarHidden(windows: [zoomed, menuBarItself], display: display, alwaysHide: false))
        XCTAssertTrue(LeftMark.menuBarHidden(windows: [zoomed, win(0, 0, 1000, 800)], display: display, alwaysHide: false))
        XCTAssertFalse(LeftMark.menuBarHidden(windows: [win(0, 0, 1000, 800, layer: 25)], display: display, alwaysHide: false))
        XCTAssertFalse(LeftMark.menuBarHidden(windows: [win(1000, 0, 1920, 1080)], display: display, alwaysHide: false))
        XCTAssertTrue(LeftMark.menuBarHidden(windows: [], display: display, alwaysHide: true))
    }
}

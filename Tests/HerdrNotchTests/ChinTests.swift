import AppKit
import XCTest
@testable import HerdrNotch

// The same made-up 1000 x 800 screen with a 200 x 30 notch as ZonesTests. Window lists are made up.
final class ChinTests: XCTestCase {
    let screen = NSRect(x: 0, y: 0, width: 1000, height: 800)
    let geo = Geometry(notchWidth: 200, notchHeight: 30)
    var menuBar: NSRect { NSRect(x: 0, y: 770, width: 1000, height: 30) }
    var leftOfNotch: NSRect { NSRect(x: 0, y: 770, width: 400, height: 30) }     // app menus
    var rightOfNotch: NSRect { NSRect(x: 600, y: 770, width: 400, height: 30) }  // icons and "<<"

    func testPillStaysUnderTheNotchAndOffTheMenuBar() {
        let r = Chin.rect(screen: screen, geo: geo, hasNotch: true)!
        XCTAssertFalse(r.intersects(menuBar))
        XCTAssertFalse(r.intersects(leftOfNotch))
        XCTAssertFalse(r.intersects(rightOfNotch))
        XCTAssertGreaterThanOrEqual(r.minX, 400)
        XCTAssertLessThanOrEqual(r.maxX, 600)
        XCTAssertLessThanOrEqual(r.width, 36)
        XCTAssertLessThanOrEqual(Chin.pill.height, 6)
    }

    func testNothingOnAScreenWithoutANotch() {
        XCTAssertNil(Chin.rect(screen: screen, geo: geo, hasNotch: false))
    }

    private func win(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, layer: Int = 0) -> [String: Any] {
        [kCGWindowLayer as String: layer, kCGWindowBounds as String: ["X": x, "Y": y, "Width": w, "Height": h]]
    }

    func testHiddenOnlyWhenAWindowCoversTheWholeDisplay() {
        let display = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let zoomed = win(0, 30, 1000, 770)                 // a maximized window stops below the menu bar
        let menuBarItself = win(0, 0, 1000, 31, layer: 24)
        XCTAssertFalse(Chin.menuBarHidden(windows: [zoomed, menuBarItself], display: display, alwaysHide: false))
        XCTAssertTrue(Chin.menuBarHidden(windows: [zoomed, win(0, 0, 1000, 800)], display: display, alwaysHide: false))
        XCTAssertFalse(Chin.menuBarHidden(windows: [win(0, 0, 1000, 800, layer: 25)], display: display, alwaysHide: false))
        // Full screen on another display doesn't hide it here.
        XCTAssertFalse(Chin.menuBarHidden(windows: [win(1000, 0, 1920, 1080)], display: display, alwaysHide: false))
        XCTAssertTrue(Chin.menuBarHidden(windows: [], display: display, alwaysHide: true))
    }
}

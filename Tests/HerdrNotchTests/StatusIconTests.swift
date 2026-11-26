import XCTest
@testable import HerdrNotch

final class StatusIconTests: XCTestCase {
    func testClickOpenedPanelWaitsForThePointer() {
        // Pointer still on the icon, opening click still down, or just moving across the screen: stays open.
        XCTAssertEqual(ClickOpen.next(inside: false, onIcon: true, pressed: true, wasPressed: true), .stay)
        XCTAssertEqual(ClickOpen.next(inside: false, onIcon: false, pressed: false, wasPressed: false), .stay)
        XCTAssertEqual(ClickOpen.next(inside: false, onIcon: false, pressed: true, wasPressed: true), .stay)
    }

    func testANewClickElsewhereCloses() {
        XCTAssertEqual(ClickOpen.next(inside: false, onIcon: false, pressed: true, wasPressed: false), .close)
        // A click on the icon itself is its toggle, not "elsewhere".
        XCTAssertEqual(ClickOpen.next(inside: false, onIcon: true, pressed: true, wasPressed: false), .stay)
    }

    func testReachingThePanelHandsOverToHover() {
        XCTAssertEqual(ClickOpen.next(inside: true, onIcon: false, pressed: false, wasPressed: false), .hover)
        XCTAssertEqual(ClickOpen.next(inside: true, onIcon: false, pressed: true, wasPressed: false), .hover)
    }

    func testBadgeCountsOnlyWaitingAgents() {
        XCTAssertEqual(ClickOpen.badge([:]), "")
        XCTAssertEqual(ClickOpen.badge([.working: 5, .done: 3, .idle: 1]), "")
        XCTAssertEqual(ClickOpen.badge([.blocked: 2, .working: 5]), "2")
    }

    func testIconIsATemplateImage() {
        XCTAssertTrue(StatusIcon.image.isTemplate)
        XCTAssertEqual(StatusIcon.image.size, NSSize(width: 18, height: 14))
    }
}

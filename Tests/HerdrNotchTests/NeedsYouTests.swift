import AppKit
import XCTest
@testable import HerdrNotch

// Made-up agents and spaces.
private func agent(_ id: String, _ state: AgentState, space: String = "wA") -> Agent {
    Agent(id: id, machine: "", spaceID: space, space: "space-\(space)", app: "claude", state: state, title: "",
          summary: "", cwd: "", isChild: false, parent: nil, statusMs: 0)
}

final class NeedsYouTests: XCTestCase {
    func testFiresOnceOnEnteringBlocked() {
        var n = NeedsYou()
        XCTAssertEqual(n.update([agent("p1", .working)], focused: nil).map(\.id), [])
        XCTAssertEqual(n.update([agent("p1", .blocked)], focused: nil).map(\.id), ["p1"])
        XCTAssertEqual(n.update([agent("p1", .blocked)], focused: nil).map(\.id), [])          // still waiting: no repeat
        XCTAssertEqual(n.update([agent("p1", .working)], focused: nil).map(\.id), [])
        XCTAssertEqual(n.update([agent("p1", .blocked)], focused: nil).map(\.id), ["p1"])     // left and came back
    }

    func testNeverForDoneIdleOrUnknown() {
        var n = NeedsYou()
        _ = n.update([agent("p1", .working)], focused: nil)
        for s in [AgentState.done, .idle, .working, .done] {
            XCTAssertEqual(n.update([agent("p1", s)], focused: nil).count, 0)
        }
        XCTAssertEqual(TerminalHerdr.state("unknown"), .idle)                                  // unknown maps to idle
    }

    func testAlreadyWaitingAtLaunchIsNotNews() {
        var n = NeedsYou()
        XCTAssertEqual(n.update([agent("p1", .blocked)], focused: nil).count, 0)
        XCTAssertEqual(n.update([agent("p1", .blocked)], focused: nil).count, 0)
    }

    func testNotForTheSpaceInFront() {
        var n = NeedsYou()
        _ = n.update([agent("p1", .working, space: "wA"), agent("p2", .working, space: "wB")], focused: "wA")
        let fired = n.update([agent("p1", .blocked, space: "wA"), agent("p2", .blocked, space: "wB")], focused: "wA")
        XCTAssertEqual(fired.map(\.id), ["p2"])
        // Looking away while p1 still waits doesn't fire it late: it was seen.
        XCTAssertEqual(n.update([agent("p1", .blocked, space: "wA"), agent("p2", .blocked, space: "wB")], focused: nil).count, 0)
    }

    func testStripSitsBelowTheMenuBarAndStaysNarrow() {
        let z = Zones(screen: NSRect(x: 0, y: 0, width: 1000, height: 800), geo: Geometry(notchWidth: 200, notchHeight: 30))
        let one = Strip.size([agent("p1", .blocked)])
        let rect = z.strip(one)
        XCTAssertLessThanOrEqual(rect.maxY, 800 - 30)                                           // top edge at or below the menu bar
        XCTAssertLessThan(one.width, Geometry.panelWidth)
        let many = Strip.size((1...9).map { agent("p\($0)", .blocked, space: String(repeating: "x", count: 80)) })
        XCTAssertLessThanOrEqual(many.width, Geometry.panelWidth)
        XCTAssertEqual(many.height, CGFloat(Strip.maxRows + 1) * Strip.rowHeight + 8)           // 4 rows and "and 5 more"
    }
}

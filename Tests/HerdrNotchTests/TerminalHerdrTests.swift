import XCTest
@testable import HerdrNotch

// Shaped like `herdr agent list` and `herdr workspace list` from herdr 0.9.5; names, paths and ids are made up.
private let agents = Data("""
{"id":"cli:agent:list","result":{"agents":[
 {"agent":"claude","agent_session":{"agent":"claude","kind":"id","source":"herdr:claude","value":"s-1"},"agent_status":"working",
  "cwd":"/Users/example/alpha","focused":true,"foreground_cwd":"/Users/example/alpha","pane_id":"wA1:p1","revision":3,
  "state_change_seq":4,"tab_id":"wA1:t1","terminal_id":"term_aaa","terminal_title":"✳ alpha","terminal_title_stripped":"alpha","workspace_id":"wA1"},
 {"agent":"claude","agent_status":"blocked","cwd":"/Users/example/beta","pane_id":"wB2:p1","terminal_title_stripped":"beta","workspace_id":"wB2"},
 {"agent":"codex","agent_status":"done","cwd":"/Users/example/gamma","pane_id":"wC3:p2","terminal_title_stripped":"","workspace_id":"wC3"},
 {"agent":"claude","agent_status":"unknown","cwd":"/Users/example/delta","pane_id":"wD4:p1","terminal_title_stripped":"delta","workspace_id":"wD4"},
 {"agent":"claude","agent_status":"something-new","cwd":"/tmp/epsilon","pane_id":"wE5:p1","workspace_id":"wE5"},
 {"agent":"claude","agent_status":"idle","cwd":"/tmp/no-pane","workspace_id":"wF6"}
]}}
""".utf8)

private let workspaces = Data("""
{"id":"cli:workspace:list","result":{"type":"workspace_list","workspaces":[
 {"active_tab_id":"wA1:t1","agent_status":"working","focused":false,"label":"Alpha","number":1,"pane_count":1,"tab_count":1,"workspace_id":"wA1"},
 {"active_tab_id":"wB2:t1","agent_status":"blocked","focused":true,"label":"Beta","number":2,"pane_count":1,"tab_count":1,"workspace_id":"wB2"},
 {"active_tab_id":"wC3:t1","agent_status":"done","focused":false,"label":"Gamma","number":3,"pane_count":2,"tab_count":1,"workspace_id":"wC3"},
 {"active_tab_id":"wD4:t1","agent_status":"unknown","focused":false,"label":"Delta","number":4,"pane_count":1,"tab_count":1,"workspace_id":"wD4"}
]}}
""".utf8)

final class TerminalHerdrTests: XCTestCase {
    func testParsesAgentsWithWorkspaceLabels() throws {
        let r = try XCTUnwrap(TerminalHerdr.parse(agents: agents, workspaces: workspaces) { _, _ in 0 })
        XCTAssertEqual(r.focused, "wB2")
        XCTAssertEqual(r.agents.map(\.id), ["wA1:p1", "wB2:p1", "wC3:p2", "wD4:p1", "wE5:p1"])   // no pane_id: skipped
        let a = r.agents[0]
        XCTAssertEqual(a.machine, "")
        XCTAssertEqual(a.spaceID, "wA1")
        XCTAssertEqual(a.space, "Alpha")
        XCTAssertEqual(a.title, "alpha")
        XCTAssertEqual(a.cwd, "/Users/example/alpha")
        XCTAssertEqual(a.appName, "Claude Code")
        XCTAssertFalse(a.isChild)
        XCTAssertEqual(r.agents[2].appName, "Codex")
        XCTAssertEqual(r.agents[4].space, "epsilon")   // no workspace label: the folder name
    }

    func testStatusMapping() throws {
        let r = try XCTUnwrap(TerminalHerdr.parse(agents: agents, workspaces: workspaces) { _, _ in 0 })
        XCTAssertEqual(r.agents.map(\.state), [.working, .blocked, .done, .idle, .idle])
        XCTAssertEqual(TerminalHerdr.state(nil), .idle)
    }

    func testErrorAnswerIsNotASnapshot() {
        let error = Data(#"{"error":{"code":"server_unavailable","message":"no server"},"id":"cli:agent:list"}"#.utf8)
        XCTAssertNil(TerminalHerdr.parse(agents: error, workspaces: workspaces) { _, _ in 0 })
        XCTAssertNil(TerminalHerdr.parse(agents: Data(), workspaces: workspaces) { _, _ in 0 })
    }

    func testStatusClock() {
        var c = StatusClock()
        XCTAssertEqual(c.since("p1", .working, nowMs: 1000), 0)        // first look: time unknown
        XCTAssertEqual(c.since("p1", .working, nowMs: 2000), 0)        // unchanged
        XCTAssertEqual(c.since("p1", .blocked, nowMs: 3000), 3000)     // changed: now
        XCTAssertEqual(c.since("p1", .blocked, nowMs: 4000), 3000)
        XCTAssertEqual(c.since("p2", .done, nowMs: 5000), 0)
    }
}

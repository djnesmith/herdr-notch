import AppKit

// Terminal herdr (the `herdr` TUI) keeps its own agents, apart from the desktop app's herdr-core (`hc`).
// Only reads and focuses: `agent list`, `workspace list`, `agent read`, `workspace focus`, `agent focus`.

enum TerminalHerdr {
    static let path: String? = ["/opt/homebrew/bin/herdr", "/usr/local/bin/herdr"]
        .first { FileManager.default.isExecutableFile(atPath: $0) }

    /// Terminal herdr can't say which terminal app it runs in, so the "you" lane follows its focused
    /// workspace only while one of these is the front app.
    static let terminals: Set<String> = ["com.googlecode.iterm2", "com.mitchellh.ghostty", "com.apple.Terminal",
                                         "net.kovidgoyal.kitty", "com.github.wez.wezterm", "org.alacritty", "dev.warp.Warp-Stable"]

    /// Terminal herdr reports no time for a status, so the app notes when it first sees each change.
    private static var clock = StatusClock()

    static func run(_ args: [String], timeout: Double = 8) -> Data? {
        guard let path else { return nil }
        return Store.run(args, timeout: timeout, executable: path)
    }

    /// nil when terminal herdr isn't installed or its server isn't answering.
    static func snapshot() -> (agents: [Agent], focused: String?)? {
        guard let a = run(["agent", "list"]), let w = run(["workspace", "list"]) else { return nil }
        let nowMs = Date().timeIntervalSince1970 * 1000
        return parse(agents: a, workspaces: w) { clock.since($0, $1, nowMs: nowMs) }
    }

    static func parse(agents: Data, workspaces: Data, since: (String, AgentState) -> Double) -> (agents: [Agent], focused: String?)? {
        func result(_ d: Data) -> [String: Any]? {
            (try? JSONSerialization.jsonObject(with: d) as? [String: Any])?["result"] as? [String: Any]
        }
        guard let list = result(agents)?["agents"] as? [[String: Any]],
              let spaces = result(workspaces)?["workspaces"] as? [[String: Any]] else { return nil }
        var labels: [String: String] = [:]
        var focused: String?
        for s in spaces {
            guard let id = s["workspace_id"] as? String else { continue }
            labels[id] = s["label"] as? String
            if s["focused"] as? Bool == true { focused = id }
        }
        let parsed = list.compactMap { t -> Agent? in
            guard let pane = t["pane_id"] as? String, let spaceID = t["workspace_id"] as? String else { return nil }
            let s = state(t["agent_status"] as? String)
            let cwd = t["cwd"] as? String ?? ""
            return Agent(id: pane, machine: "", spaceID: spaceID,
                         space: labels[spaceID] ?? (cwd as NSString).lastPathComponent,
                         app: t["agent"] as? String ?? "agent", state: s,
                         title: t["terminal_title_stripped"] as? String ?? "", summary: "", cwd: cwd,
                         isChild: false, parent: nil, statusMs: since(pane, s))
        }
        return (parsed, focused)
    }

    /// herdr's states are idle, working, blocked, done and unknown. Unknown or new ones show as idle.
    static func state(_ s: String?) -> AgentState { s.flatMap(AgentState.init(rawValue:)) ?? .idle }
}

struct StatusClock {
    private var seen: [String: (state: AgentState, ms: Double)] = [:]

    /// When an agent entered its current state, in ms. 0 if it was already in it at the first look.
    mutating func since(_ id: String, _ state: AgentState, nowMs: Double) -> Double {
        if let s = seen[id], s.state == state { return s.ms }
        let ms = seen[id] == nil ? 0 : nowMs
        seen[id] = (state, ms)
        return ms
    }
}

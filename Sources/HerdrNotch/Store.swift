import AppKit
import SwiftUI

// Everything the views show. Polls herdr-core (`hc`) and turns its answer into view state.

final class Store: ObservableObject {
    @Published var machines: [MachineGroup] = []        // after the machine filter
    @Published var machineIDs: [String] = []            // every machine with agents
    @Published var counts: [AgentState: Int] = [:]      // after the machine filter
    @Published var error: String?
    @Published var expanded = false
    @Published var showIdle = UserDefaults.standard.bool(forKey: "showIdle") {
        didSet { if persist { UserDefaults.standard.set(showIdle, forKey: "showIdle") } }
    }
    /// nil shows every machine.
    @Published var machineFilter: String? = UserDefaults.standard.string(forKey: "machine") {
        didSet { if persist { UserDefaults.standard.set(machineFilter, forKey: "machine") }; rebuild() }
    }
    /// The open panel shows either the list of workspaces or the trace over time.
    @Published var traceMode = UserDefaults.standard.bool(forKey: "traceMode") {
        didSet { if persist { UserDefaults.standard.set(traceMode, forKey: "traceMode") }; retrace() }
    }
    /// How far back the trace looks, in seconds.
    @Published var range: Double = { let r = UserDefaults.standard.double(forKey: "range"); return r > 0 ? r : 3600 }() {
        didSet { if persist { UserDefaults.standard.set(range, forKey: "range") }; retrace() }
    }
    @Published var trace: Trace?
    @Published var mini: Trace?                         // the last hour, for the small trace in the closed notch
    /// A line the closed notch shows for a few seconds when an agent finishes or starts needing you.
    struct Announcement: Equatable { let id = UUID(); let text: String; let state: AgentState }
    @Published var announcement: Announcement?
    @Published var newDone = 0                          // finished since you last opened the panel
    @Published var offline: [String] = []               // machines Herdr has lost its connection to
    @Published var waitingSince: Double?                // when the longest-waiting agent started needing you (ms)

    let persist: Bool
    let recorder: Recorder
    private var lastLooked = UserDefaults.standard.double(forKey: "lastLooked")
    private var pollCount = 0

    init(persist: Bool = true) {
        self.persist = persist
        recorder = Recorder(persist: persist)
        if lastLooked == 0 { lastLooked = Date().timeIntervalSince1970 }
    }

    var panelWidth: CGFloat { traceMode ? Geometry.traceWidth : Geometry.panelWidth }
    var earWidth: CGFloat { waitingSince != nil || newDone > 0 ? Geometry.wideEar : Geometry.ear }
    @Published var hoveredID: String?                   // workspace whose detail card is showing
    @Published var pointerRow: String?                  // row under the pointer right now
    var activeRow: String? { pointerRow ?? hoveredID }
    @Published var tail: [String]?                      // latest terminal lines for the card; nil while loading
    @Published var cardHeight: CGFloat = 200

    private(set) var agents: [Agent] = []
    private var pendingHover: DispatchWorkItem?
    private let queue = DispatchQueue(label: "herdr-notch.poll")
    private let tailQueue = DispatchQueue(label: "herdr-notch.tail")
    private var polling = false

    static let rowHeight: CGFloat = 46
    static let sectionHeight: CGFloat = 30

    static let hc: String = {
        let home = NSHomeDirectory()
        for p in ["\(home)/.local/bin/hc", "/opt/homebrew/bin/hc", "/usr/local/bin/hc"]
        where FileManager.default.isExecutableFile(atPath: p) { return p }
        return "\(home)/.local/bin/hc"
    }()
    static let herdrApp = "\(NSHomeDirectory())/.local/bin/herdr-app"

    // MARK: derived

    struct SectionModel: Identifiable {
        let machine: MachineGroup; let rows: [Workspace]; let hidden: Int
        var id: String { machine.id }
    }
    var sections: [SectionModel] {
        machines.map { m in
            let rows = m.workspaces.filter { showIdle || $0.state != .idle }
            return SectionModel(machine: m, rows: rows, hidden: m.workspaces.count - rows.count)
        }
    }
    var idleSpaces: Int { machines.reduce(0) { $0 + $1.workspaces.filter { $0.state == .idle }.count } }
    var hasEars: Bool {
        // Always on while Herdr has agents: the mini trace is worth seeing even when nothing is running right now.
        error != nil || !offline.isEmpty || !agents.isEmpty
    }
    var showsSectionHeaders: Bool { machineFilter == nil && machineIDs.count > 1 }
    var showsSelector: Bool { machineIDs.count > 1 }
    var hovered: Workspace? {
        guard let id = hoveredID else { return nil }
        for m in machines { if let w = m.workspaces.first(where: { $0.id == id }) { return w } }
        return nil
    }

    /// Height the open panel needs for what it shows, up to the maximum (then the list scrolls).
    func panelHeight(_ geo: Geometry) -> CGFloat {
        let notices: CGFloat = (error == nil ? 0 : 26) + (offline.isEmpty ? 0 : 26)
        if traceMode, let t = trace {
            return min(Geometry.maxPanelHeight, 10 + (showsSelector ? 34 : 0) + notices + TraceLayout.height(t) + 38)
        }
        let rows = sections.reduce(0) { $0 + $1.rows.count }
        let heads = showsSectionHeaders ? CGFloat(sections.count) * (Self.sectionHeight + 4) : 6
        let list = CGFloat(rows) * Self.rowHeight + heads + (rows == 0 ? 64 : 6)
        let chrome: CGFloat = 10 + (showsSelector ? 34 : 0) + 32 + 38 + notices
        return min(Geometry.maxPanelHeight, chrome + list)
    }

    // MARK: polling

    func start() {
        poll()
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.poll() }
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refreshTail() }
    }

    func poll() {
        if polling { return }
        polling = true
        pollCount += 1
        let checkMachines = pollCount % 5 == 1
        let front = NSWorkspace.shared.frontmostApplication
        let herdrInFront = front?.localizedName == "Herdr"
        let terminalInFront = TerminalHerdr.terminals.contains(front?.bundleIdentifier ?? "")
        queue.async {
            let result = Self.snapshot()
            let focus = Self.source == .terminal ? (terminalInFront ? Self.terminalFocus : nil)
                                                 : (herdrInFront ? Self.focusedSpace() : nil)
            let offline = !checkMachines ? nil : (Self.source == .desktop ? Self.offlineMachines() : [])
            DispatchQueue.main.async {
                self.polling = false
                if let offline { self.offline = offline }
                switch result {
                case .success(let agents):
                    let now = Date().timeIntervalSince1970
                    let changes = self.recorder.record(agents, now: now)
                    let name = focus.flatMap { id in agents.first { $0.spaceID == id }?.space } ?? "Herdr"
                    self.recorder.recordYou(spaceID: focus, space: name, now: now)
                    self.agents = agents; self.error = nil; self.rebuild()
                    self.announce(changes)
                case .failure(let e): self.error = e.message
                }
            }
        }
    }

    /// The Herdr space in front of you right now.
    static func focusedSpace() -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: herdrApp)
        p.arguments = ["status"]
        let out = Pipe()
        p.standardOutput = out; p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return nil }
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) { if p.isRunning { p.terminate() } }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["space"] as? String
    }

    static func offlineMachines() -> [String]? {
        guard let data = run(["ls", "--json"], timeout: 5),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = obj["machines"] as? [[String: Any]] else { return nil }
        return list.compactMap { ($0["state"] as? String) == "connected" ? nil : $0["name"] as? String }
    }

    /// Say what just changed in the closed notch: one line, a few seconds, then it folds away.
    func announce(_ changes: [Transition]) {
        let news = changes.filter { !$0.agent.isChild && ($0.to == .blocked || $0.to == .done) }
            .sorted { $0.to.rank < $1.to.rank }
        guard let first = news.first, !expanded else { return }
        var text = first.to == .blocked ? "\(first.agent.space) needs you" : "\(first.agent.space) finished"
        if news.count > 1 { text += " and \(news.count - 1) more" }
        let note = Announcement(text: text, state: first.to)
        withAnimation(Motion.open) { announcement = note }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if self.announcement == note { withAnimation(Motion.close) { self.announcement = nil } }
        }
    }

    /// Opening the panel counts as looking: what finished before now is no longer news.
    func markLooked() {
        lastLooked = Date().timeIntervalSince1970
        if persist { UserDefaults.standard.set(lastLooked, forKey: "lastLooked") }
        rebuild()
    }

    func retrace() {
        trace = traceMode ? recorder.trace(range: range, now: Date().timeIntervalSince1970, machine: machineFilter) : nil
    }

    func jump(toAgent id: String) {
        if let a = agents.first(where: { $0.id == id }) { jump(to: a) }
    }

    struct PollError: Error { let message: String }

    static func run(_ args: [String], firstLineOnly: Bool = false, timeout: Double = 8, executable: String = hc) -> Data? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        p.standardInput = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { if p.isRunning { p.terminate() } }
        var data = Data()
        let h = out.fileHandleForReading
        while true {
            let chunk = h.availableData
            if chunk.isEmpty { break }
            data.append(chunk)
            if firstLineOnly && chunk.contains(0x0A) { break }
        }
        if p.isRunning { p.terminate() }
        return data
    }

    /// Where the agents come from: terminal herdr (`herdr`) or the desktop app's herdr-core (`hc`).
    enum Source: String { case terminal, desktop }
    private(set) static var source = Source.desktop
    private static var terminalFocus: String?

    /// Terminal herdr when it answers, else the desktop app. `defaults write com.djnesmith.herdr-notch source
    /// terminal` (or `desktop`) forces one; `defaults delete com.djnesmith.herdr-notch source` goes back to automatic.
    static func snapshot() -> Result<[Agent], PollError> {
        let forced = UserDefaults.standard.string(forKey: "source").flatMap(Source.init(rawValue:))
        if forced != .desktop, let t = TerminalHerdr.snapshot() {
            source = .terminal; terminalFocus = t.focused
            return .success(t.agents)
        }
        if forced == .terminal {
            source = .terminal; terminalFocus = nil
            return .failure(PollError(message: "Terminal herdr isn't answering. Start herdr."))
        }
        source = .desktop
        return desktopSnapshot()
    }

    /// `hc events --json` prints one full snapshot line covering every machine, then follows. We take that line.
    static func desktopSnapshot() -> Result<[Agent], PollError> {
        guard FileManager.default.isExecutableFile(atPath: hc) else {
            return .failure(PollError(message: "Herdr's hc command isn't installed at ~/.local/bin/hc"))
        }
        guard let data = run(["events", "--json"], firstLineOnly: true),
              let nl = data.firstIndex(of: 0x0A) ?? (data.isEmpty ? nil : data.endIndex),
              let obj = try? JSONSerialization.jsonObject(with: data[..<nl]) as? [String: Any],
              let terms = obj["terminals"] as? [[String: Any]]
        else { return .failure(PollError(message: "Herdr isn't answering. Open Herdr to start it.")) }
        return .success(terms.compactMap(parse))
    }

    static func parse(_ t: [String: Any]) -> Agent? {
        guard (t["state"] as? String) == "live",
              let address = t["address"] as? String,
              let status = t["status"] as? [String: Any],
              let s = status["state"] as? String, let state = AgentState(rawValue: s)
        else { return nil }
        let labels = t["labels"] as? [String: Any] ?? [:]
        let machine = address.contains("/") ? String(address.split(separator: "/")[0]) : ""
        let cwd = t["cwd"] as? String ?? ""
        var space = (labels["where"] as? String ?? "").components(separatedBy: " / ").first ?? ""
        if space.isEmpty { space = (cwd as NSString).lastPathComponent }
        let rawSpace = labels["herdr.space"] as? String ?? space
        var title = (t["title"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        if title.isEmpty { title = t["name"] as? String ?? "" }
        if let bar = title.range(of: " | ", options: .backwards), title[bar.upperBound...] == space { title = String(title[..<bar.lowerBound]) }
        return Agent(id: address, machine: machine,
                     spaceID: machine.isEmpty ? rawSpace : "\(machine)/\(rawSpace)",
                     space: space, app: status["app"] as? String ?? "agent", state: state, title: title,
                     summary: labels["herdr.summary"] as? String ?? "", cwd: cwd,
                     isChild: t["parent"] as? String != nil, parent: t["parent"] as? String,
                     statusMs: t["status_ms"] as? Double ?? 0)
    }

    func apply(_ list: [Agent]) { agents = list; rebuild() }

    func rebuild() {
        let ids = Set(agents.map { $0.machine })
        machineIDs = ids.sorted { a, b in a.isEmpty ? true : (b.isEmpty ? false : a < b) }
        if let f = machineFilter, !ids.isEmpty, !ids.contains(f) { machineFilter = nil; return }
        let shown = agents.filter { machineFilter == nil || $0.machine == machineFilter }
        var c: [AgentState: Int] = [:]
        for a in shown { c[a.state, default: 0] += 1 }
        let spaces = Dictionary(grouping: shown, by: { $0.spaceID }).map { (id, list) -> Workspace in
            let sorted = list.sorted { ($0.state.rank, -$0.statusMs) < ($1.state.rank, -$1.statusMs) }
            return Workspace(id: id, machine: sorted[0].machine, name: sorted[0].space, agents: sorted)
        }
        let byMachine = Dictionary(grouping: spaces, by: { $0.machine })
        machines = machineIDs.filter { byMachine[$0] != nil }.map { m in
            MachineGroup(id: m, workspaces: byMachine[m]!.sorted {
                ($0.state.rank, -$0.top.statusMs) < ($1.state.rank, -$1.top.statusMs)
            })
        }
        counts = c
        newDone = shown.filter { $0.state == .done && !$0.isChild && $0.statusMs / 1000 > lastLooked }.count
        waitingSince = shown.filter { $0.state == .blocked }.map { $0.statusMs }.filter { $0 > 0 }.min()
        retrace()
        mini = recorder.trace(range: 3600, now: Date().timeIntervalSince1970, machine: machineFilter, limit: 4)
        if hoveredID != nil && hovered == nil { clearHover() }
    }

    // MARK: detail card

    /// Show a workspace's card after a short dwell, so sweeping across rows doesn't flicker through them.
    func requestHover(_ id: String) {
        pendingHover?.cancel()
        guard id != hoveredID else { return }
        let w = DispatchWorkItem { [weak self] in
            guard let self, self.expanded else { return }
            withAnimation(Motion.card) { self.hoveredID = id }
            self.tail = nil
            self.refreshTail()
        }
        pendingHover = w
        DispatchQueue.main.asyncAfter(deadline: .now() + (hoveredID == nil ? 0.22 : 0.14), execute: w)
    }
    func cancelPendingHover() { pendingHover?.cancel() }
    func clearHover() {
        pendingHover?.cancel()
        withAnimation(Motion.card) { hoveredID = nil; pointerRow = nil }
        tail = nil
    }

    func refreshTail() {
        guard expanded, let w = hovered else { return }
        let address = w.top.id
        tailQueue.async {
            let lines = Self.readTail(address)
            DispatchQueue.main.async {
                guard self.hovered?.top.id == address else { return }
                if self.tail != lines { self.tail = lines }
            }
        }
    }

    /// The last things an agent said, rebuilt into readable paragraphs: the terminal's hard-wrapped lines are joined
    /// back into sentences, and its borders, prompts, tool calls and status bars are left out. Newest last.
    static func readTail(_ address: String, keep: Int = 2) -> [String] {
        let data = source == .terminal ? TerminalHerdr.run(["agent", "read", address, "--lines", "20"], timeout: 6)
                                       : run(["read", address, "--lines", "20"], timeout: 6)
        // Terminal herdr answers a failed read with a JSON error instead of text.
        guard let data, let text = String(data: data, encoding: .utf8), !text.hasPrefix("{\"error\"") else { return [] }
        let chrome = ["auto mode on", "to manage", "for shortcuts", "bypass permissions", "/restart to apply", "esc to interrupt",
                      "Ask Codex", "/clear to save", " default · ", "context left", "Compacted while idle", "still running in background",
                      "Skills restored", "Referenced file", "ctrl+o to expand", "ctrl+r to expand"]
        let speech: Set<Character> = ["●", "⏺", "•", "※"]             // starts something the agent said
        let noise: Set<Character> = ["⎿", "└", "∟", "❯", "›", ">", "⏵", "✻", "✶", "✳", "✢", "✽", "*"]   // tool output, prompts, spinners
        let toolCall = try! NSRegularExpression(pattern: "^[A-Z][A-Za-z]+(\\(.*|\\s+\\d+ (lines?|files?).*)$")
        let listItem = try! NSRegularExpression(pattern: "^(- |\\d+[.)] )")
        func matches(_ r: NSRegularExpression, _ t: String) -> Bool { r.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) != nil }

        var blocks: [String] = []
        var current = ""
        var skipping = false            // inside tool output or a prompt: drop lines until the next blank line or speech
        func close() {
            let t = current.trimmingCharacters(in: .whitespacesAndNewlines)
            // "Worked for 1h 27m", "Brewed for 2m": a timer line, not something the agent said.
            let timer = t.range(of: "^[A-Z]\\p{L}+ for \\d", options: .regularExpression) != nil
            if t.count >= 16 && !timer { blocks.append(t) }
            current = ""
        }
        for raw in text.components(separatedBy: "\n") {
            let scalars = raw.unicodeScalars.filter { !(0x2500...0x259F).contains($0.value) && $0.value != 0x1B }
            var line = String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespaces)
            if line.isEmpty { close(); skipping = false; continue }
            if chrome.contains(where: { line.contains($0) }) { continue }
            let first = line.first!
            if speech.contains(first) {
                close(); skipping = false
                line = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                if line.lowercased().hasPrefix("recap:") { line = "Recap: " + line.dropFirst(6).trimmingCharacters(in: .whitespaces) }
                if matches(toolCall, line) { skipping = true; continue }
            } else if noise.contains(first) {
                close(); skipping = true; continue
            }
            if skipping { continue }
            line = line.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
            if matches(listItem, line) {
                current += (current.isEmpty ? "" : "\n") + "–  " + line.replacingOccurrences(of: "^(- |\\d+[.)] )", with: "", options: .regularExpression)
            } else {
                current += (current.isEmpty || current.hasSuffix("\n") ? "" : " ") + line
            }
        }
        close()
        return Array(blocks.suffix(keep))
    }

    func jump(to a: Agent) {
        expanded = false
        let terminal = Self.source == .terminal
        queue.async {
            let commands: [(String, [String])]
            if terminal {
                commands = TerminalHerdr.path.map { [($0, ["workspace", "focus", a.spaceID]), ($0, ["agent", "focus", a.id])] } ?? []
            } else {
                commands = [["do", "space.select", "--id", a.spaceID], ["do", "pane.focus", "--terminal", a.id]].map { (Self.herdrApp, $0) }
            }
            for (executable, args) in commands {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: executable)
                p.arguments = args
                p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
                try? p.run(); p.waitUntilExit()
            }
            DispatchQueue.main.async {
                let apps = NSWorkspace.shared.runningApplications
                let target = terminal ? apps.first { TerminalHerdr.terminals.contains($0.bundleIdentifier ?? "") }
                                      : apps.first { $0.localizedName == "Herdr" }
                target?.activate()
            }
        }
    }
}

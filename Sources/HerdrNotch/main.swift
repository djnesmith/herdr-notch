import AppKit
import SwiftUI

// Herdr Notch: agent statuses from every Herdr machine, living in the MacBook notch.
//
//   HerdrNotch                      run the app
//   HerdrNotch --dump               print what the notch would show, to check the data
//   HerdrNotch --render <folder>    draw the views to PNG files without touching the screen
//                                   (--demo: invented agents, for screenshots; --machine <name>: filter;
//                                    --backdrop <0...1 | clear>: grey level behind the views)

let cli = CommandLine.arguments

if cli.contains("--dump") {
    switch Store.snapshot() {
    case .failure(let e):
        print("error:", e.message)
        exit(1)
    case .success(let agents):
        let store = Store(persist: false)
        store.machineFilter = nil
        store.apply(agents)
        print("source:", Store.source.rawValue)
        print("counts:", store.counts.map { "\($0.key.rawValue)=\($0.value)" }.sorted().joined(separator: " "))
        for machine in store.machines {
            print(machine.name)
            for w in machine.workspaces {
                print("  [\(w.state.rawValue)] \(w.name) (\(w.agents.count)) \(w.top.id): \(w.top.title)")
            }
        }
        exit(0)
    }
}

if let i = cli.firstIndex(of: "--render"), cli.count > i + 1 {
    // Nothing here writes saved choices or recorded history.
    _ = NSApplication.shared
    let demo = cli.contains("--demo")
    let now = Date().timeIntervalSince1970
    let agents: [Agent]
    if demo {
        agents = Demo.agents(now: now)
    } else if case .success(let live) = Store.snapshot() {
        agents = live
    } else {
        print("Herdr isn't answering; try --demo")
        exit(1)
    }
    let geo = Geometry(notchWidth: 190, notchHeight: 32)
    // A grey level behind the views, or "clear" to keep them see-through for compositing.
    let backdropArg = cli.firstIndex(of: "--backdrop").map { cli[$0 + 1] }
    let backdrop: Color = backdropArg == "clear" ? .clear : Color(white: backdropArg.flatMap(Double.init) ?? 0.42)
    let wide = Geometry.traceWidth + 2 * (Geometry.cardGap + Geometry.cardWidth + Geometry.margin)
    let tall = Geometry.maxPanelHeight + Geometry.margin + geo.detach

    for name in ["list", "trace", "closed", "announce"] {
        let store = Store(persist: false)
        store.machineFilter = cli.firstIndex(of: "--machine").map { cli[$0 + 1] }
        _ = store.recorder.record(agents, now: now)
        if demo { Demo.fill(store.recorder, agents: agents, now: now) }
        store.apply(agents)
        store.expanded = name == "list" || name == "trace"
        store.traceMode = name == "trace"
        if name == "announce" { store.announcement = .init(text: "\(agents.first?.space ?? "checkout-api") needs you", state: .blocked) }
        if name == "list", let w = store.sections.flatMap({ $0.rows }).first {
            store.hoveredID = w.id
            store.tail = demo ? Demo.tail : Store.readTail(w.top.id)
        }
        let size = store.expanded ? NSSize(width: wide, height: tall)
                                  : NSSize(width: geo.notchWidth, height: geo.notchHeight)
        let view = NSHostingView(rootView: RootView(store: store, geo: geo).background(backdrop))
        view.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: view.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = view
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(1.2))
        let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let file = URL(fileURLWithPath: cli[i + 1]).appendingPathComponent("\(name).png")
        try! bitmap.representation(using: .png, properties: [:])!.write(to: file)
        print(file.path)
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

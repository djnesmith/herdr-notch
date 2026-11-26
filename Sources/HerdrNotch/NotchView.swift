import AppKit
import SwiftUI

// The notch itself: closed counters, the open panel, the workspace list and its controls.

// MARK: - Views

/// Square on top while it is the notch, rounded all round once it floats free.
struct NotchShape: InsettableShape {
    var radius: CGFloat
    var topRadius: CGFloat = 0
    var inset: CGFloat = 0
    func inset(by amount: CGFloat) -> NotchShape { var c = self; c.inset += amount; return c }
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(radius, topRadius) }
        set { radius = newValue.first; topRadius = newValue.second }
    }
    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let b = max(0, min(radius - inset, r.height / 2)), t = max(0, min(topRadius - inset, r.height / 2))
        var p = Path()
        p.move(to: CGPoint(x: r.minX + t, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - t, y: r.minY))
        if t > 0 { p.addArc(center: CGPoint(x: r.maxX - t, y: r.minY + t), radius: t, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false) }
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - b))
        p.addArc(center: CGPoint(x: r.maxX - b, y: r.maxY - b), radius: b, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: r.minX + b, y: r.maxY))
        p.addArc(center: CGPoint(x: r.minX + b, y: r.maxY - b), radius: b, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + t))
        if t > 0 { p.addArc(center: CGPoint(x: r.minX + t, y: r.minY + t), radius: t, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false) }
        p.closeSubpath()
        return p
    }
}

/// One status mark: a turning ring while working, a breathing dot when it needs you, a plain dot otherwise.
struct Mark: View {
    let state: AgentState
    var size: CGFloat = 8
    @State private var on = false
    var body: some View {
        Group {
            switch state {
            case .working where !Motion.reduced:
                Circle().trim(from: 0.12, to: 0.82)
                    .stroke(state.color, style: StrokeStyle(lineWidth: max(1.4, size * 0.2), lineCap: .round))
                    .rotationEffect(.degrees(on ? 360 : 0))
                    .animation(.linear(duration: 1.1).repeatForever(autoreverses: false), value: on)
            case .working:
                Circle().stroke(state.color, lineWidth: max(1.4, size * 0.2))
            case .blocked where !Motion.reduced:
                Circle().fill(state.color)
                    .overlay(Circle().stroke(state.color.opacity(0.55), lineWidth: 1.5).scaleEffect(on ? 2.1 : 1).opacity(on ? 0 : 1))
                    .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: on)
            default:
                Circle().fill(state.color)
            }
        }
        .frame(width: size, height: size)
        .onAppear { on = true }
        .accessibilityLabel(state.label)
    }
}

struct Count: View {
    let state: AgentState
    let n: Int
    var detail: String? = nil
    var body: some View {
        HStack(spacing: 5) {
            Mark(state: state, size: 8)
            Text("\(n)").font(.system(size: 12, weight: .semibold)).monospacedDigit().foregroundColor(Ink.primary)
                .contentTransition(.numericText())
            if let detail, !detail.isEmpty {
                Text(detail).font(.system(size: 12)).monospacedDigit().foregroundColor(state.color).fixedSize()
            }
        }
        .animation(Motion.select, value: n)
    }
}

struct RootView: View {
    @ObservedObject var store: Store
    let geo: Geometry
    @Namespace private var rows

    /// Fork: closed, the app is the hardware notch and nothing else. No counters, trace or announcement
    /// beside or under it, whatever the agents are doing: those sat over the menu bar.
    static func size(open: Bool, store: Store, geo: Geometry) -> CGSize {
        open ? CGSize(width: store.panelWidth, height: store.panelHeight(geo)) : CGSize(width: geo.notchWidth, height: geo.notchHeight)
    }

    var body: some View {
        let open = store.expanded
        let size = Self.size(open: open, store: store, geo: geo)
        let w = size.width, h = size.height
        let closedRadius: CGFloat = 10
        ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                if open {
                    panel.transition(.asymmetric(
                        insertion: .frost.combined(with: .scale(scale: 0.96, anchor: .top)).animation(Motion.open.delay(0.05)),
                        removal: .frost.animation(.easeOut(duration: 0.13))))
                }
            }
            .frame(width: w, height: h, alignment: .top)
            .background(PanelBackdrop(open: open, closedRadius: closedRadius))
            .clipShape(NotchShape(radius: open ? 22 : closedRadius, topRadius: open ? 22 : 0))
            .overlay(NotchShape(radius: open ? 22 : closedRadius, topRadius: open ? 22 : 0).strokeBorder(Color.white.opacity(open ? 0.12 : 0), lineWidth: 1))
            .compositingGroup()
            .shadow(color: .black.opacity(open ? 0.3 : 0), radius: 16, y: 8)
            .opacity(open ? 1 : 0)
            .offset(y: open ? geo.detach : 0)

            if open, let space = store.hovered {
                DetailCard(store: store, space: space)
                    .id(space.id)
                    .offset(x: store.panelWidth / 2 + Geometry.cardGap + Geometry.cardWidth / 2, y: geo.detach)
                    .transition(.frost.combined(with: .offset(x: -12)).combined(with: .scale(scale: 0.97, anchor: .leading)))
            }
        }
        .animation(open ? Motion.open : Motion.close, value: open)
        .animation(Motion.open, value: h)
        .animation(Motion.open, value: w)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 10)
            if store.showsSelector { MachineSelector(store: store).frame(height: 34) }
            if let e = store.error { notice(e) }
            if !store.offline.isEmpty {
                notice("\(store.offline.joined(separator: ", ")) \(store.offline.count == 1 ? "is" : "are") offline. Their agents are not counted.")
            }
            if store.traceMode, let t = store.trace {
                TraceView(store: store, trace: t).transition(.frost)
            } else {
                list.transition(.frost)
            }
            footer
        }
        .frame(width: store.panelWidth, height: store.panelHeight(geo), alignment: .top)
    }

    func notice(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill").font(.system(size: 11.5)).foregroundColor(.orange)
            .lineLimit(1).padding(.horizontal, 18).frame(height: 26)
    }

    var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            summary
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(store.sections) { sec in
                        if store.showsSectionHeaders { SectionHeader(machine: sec.machine, hidden: sec.hidden) }
                        ForEach(sec.rows) { w in Row(store: store, space: w, ns: rows) }
                    }
                    if store.sections.allSatisfy({ $0.rows.isEmpty }) && store.error == nil { empty }
                }.padding(.top, store.showsSectionHeaders ? 0 : 6).padding(.bottom, 6)
                .id(store.machineFilter ?? "\u{0}all")
                .transition(.frost)
            }
            .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.94),
                                         .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
        }
    }

    var empty: some View {
        let idle = store.idleSpaces
        return Text(idle > 0 ? "Everything here is idle." : "No agents running\(store.machineFilter == nil ? "" : " on \(machineName(store.machineFilter!))").")
            .font(.system(size: 12.5)).foregroundColor(Ink.secondary)
            .frame(maxWidth: .infinity).frame(height: 58)
    }

    var summary: some View {
        // Idle is left out: it never asks anything of you.
        let shown = [AgentState.blocked, .working, .done].filter { store.counts[$0, default: 0] > 0 }
        return HStack(spacing: 14) {
            ForEach(shown, id: \.self) { s in
                HStack(spacing: 6) {
                    Mark(state: s, size: 8)
                    Text("\(store.counts[s]!)").font(.system(size: 12.5, weight: .semibold)).monospacedDigit().foregroundColor(Ink.primary)
                        .contentTransition(.numericText())
                    Text(s.label).font(.system(size: 12.5)).foregroundColor(Ink.secondary)
                }
            }
            if shown.isEmpty { Text("Nothing running").font(.system(size: 12.5)).foregroundColor(Ink.secondary) }
            Spacer()
        }
        .padding(.horizontal, 18).frame(height: 32)
        .animation(Motion.select, value: store.machineFilter)
    }

    var footer: some View {
        HStack(spacing: 4) {
            ModeToggle(store: store)
            if !store.traceMode && store.idleSpaces > 0 {
                QuietButton(title: store.showIdle ? "Hide idle" : "Show \(store.idleSpaces) idle") {
                    withAnimation(Motion.open) { store.showIdle.toggle() }
                }
            }
            Spacer()
            QuietButton(title: "Quit") { NSApp.terminate(nil) }
        }
        .padding(.horizontal, 10).frame(height: 38, alignment: .top)
    }
}

/// Switch the panel between the list of workspaces and the trace over time.
struct ModeToggle: View {
    @ObservedObject var store: Store
    @Namespace private var ns
    var body: some View {
        HStack(spacing: 2) {
            ForEach([false, true], id: \.self) { trace in
                let on = store.traceMode == trace
                Button { withAnimation(Motion.open) { store.traceMode = trace } } label: {
                    Label(trace ? "Trace" : "List", systemImage: trace ? "chart.bar.xaxis" : "list.bullet")
                        .labelStyle(.titleAndIcon).font(.system(size: 11.5, weight: on ? .semibold : .medium))
                        .foregroundColor(on ? Ink.primary : Ink.tertiary)
                        .padding(.horizontal, 9).frame(height: 24)
                        .background { if on { Capsule().fill(Ink.selected).matchedGeometryEffect(id: "mode", in: ns) } }
                        .contentShape(Capsule())
                }.buttonStyle(PressStyle())
            }
        }
    }
}

/// Pick one machine, or all of them. The closed notch counts follow the choice too.
struct MachineSelector: View {
    @ObservedObject var store: Store
    @Namespace private var ns
    @State private var hover: String?

    var body: some View {
        let options: [String?] = [nil] + store.machineIDs.map { Optional($0) }
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(options, id: \.self) { id in
                    let selected = store.machineFilter == id
                    let key = id ?? "\u{0}all"
                    Button { withAnimation(Motion.select) { store.machineFilter = id } } label: {
                        Text(id.map(machineName) ?? "All")
                            .font(.system(size: 12, weight: selected ? .semibold : .medium))
                            .foregroundColor(selected ? Ink.primary : (hover == key ? Ink.primary : Ink.secondary))
                            .lineLimit(1).fixedSize()
                            .padding(.horizontal, 10).frame(height: 26)
                            .background {
                                if selected {
                                    Capsule().fill(Ink.selected).matchedGeometryEffect(id: "pill", in: ns)
                                } else if hover == key {
                                    Capsule().fill(Ink.hover)
                                }
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressStyle())
                    .onHover { h in withAnimation(Motion.quick) { hover = h ? key : (hover == key ? nil : hover) } }
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }.padding(.horizontal, 10)
        }
    }
}

struct QuietButton: View {
    let title: String
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 11.5, weight: .medium)).foregroundColor(hover ? Ink.primary : Ink.tertiary)
                .padding(.horizontal, 9).frame(height: 24)
                .background(Capsule().fill(hover ? Ink.hover : .clear))
                .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
        .onHover { h in withAnimation(Motion.quick) { hover = h } }
    }
}

struct SectionHeader: View {
    let machine: MachineGroup
    let hidden: Int
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: machine.id.isEmpty ? "laptopcomputer" : "server.rack").font(.system(size: 10, weight: .medium))
            Text(machine.name).font(.system(size: 11.5, weight: .semibold))
            if hidden > 0 { Text("\(hidden) idle").font(.system(size: 11.5)) }
            Spacer()
        }
        .foregroundColor(Ink.tertiary)
        .padding(.horizontal, 18).frame(height: Store.sectionHeight, alignment: .bottom).padding(.bottom, 4)
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct AgentDots: View {
    let agents: [Agent]
    var body: some View {
        HStack(spacing: 3) {
            ForEach(agents.prefix(6)) { a in
                Circle().fill(a.state.color).frame(width: a.isChild ? 4 : 5.5, height: a.isChild ? 4 : 5.5)
            }
            if agents.count > 6 { Text("+\(agents.count - 6)").font(.system(size: 11.5)).foregroundColor(Ink.tertiary) }
        }
    }
}

struct Row: View {
    @ObservedObject var store: Store
    let space: Workspace
    let ns: Namespace.ID
    var body: some View {
        let active = store.activeRow == space.id
        Button { store.jump(to: space.top) } label: {
            HStack(spacing: 11) {
                Mark(state: space.state, size: 9).frame(width: 14)
                VStack(alignment: .leading, spacing: 1.5) {
                    Text(space.name).font(.system(size: 13, weight: .medium)).foregroundColor(Ink.primary).lineLimit(1)
                    Text(space.top.title.isEmpty ? "\(space.top.appName), \(space.state.label)" : space.top.title)
                        .font(.system(size: 11.5)).foregroundColor(Ink.secondary).lineLimit(1)
                }
                Spacer(minLength: 10)
                if space.agents.count > 1 { AgentDots(agents: space.agents) }
                Text(ago(space.top.statusMs)).font(.system(size: 11.5)).monospacedDigit().foregroundColor(Ink.tertiary)
                    .frame(minWidth: 24, alignment: .trailing)
            }
            .padding(.horizontal, 12).frame(height: Store.rowHeight - 2)
            .background {
                // One highlight shared by every row, so it glides from row to row instead of blinking.
                if active {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Ink.hover)
                        .matchedGeometryEffect(id: "highlight", in: ns)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .padding(.horizontal, 6).frame(height: Store.rowHeight)
        .onHover { h in
            if h {
                withAnimation(Motion.glide) { store.pointerRow = space.id }
                store.requestHover(space.id)
            } else {
                store.cancelPendingHover()
                // Wait a beat: if the pointer went to another row, that row has already taken the highlight.
                DispatchQueue.main.async {
                    if store.pointerRow == space.id { withAnimation(Motion.glide) { store.pointerRow = nil } }
                }
            }
        }
        .accessibilityLabel("\(space.name), \(space.state.label)")
    }
}

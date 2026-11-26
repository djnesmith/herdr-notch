import AppKit
import SwiftUI

// Fork: a strip under the notch when an agent starts needing you, since the closed notch shows nothing.

/// Which agents go on the strip. herdr's `blocked` is its "waiting on you" state (a permission, question or
/// trust prompt on screen); done, idle, working and unknown never count. An agent fires once when it enters
/// `blocked`, and again only after it has left and come back. Not while its space is the one in front of you.
struct NeedsYou {
    private var waiting: Set<String> = []
    private var primed = false

    mutating func update(_ agents: [Agent], focused: String?) -> [Agent] {
        let blocked = agents.filter { $0.state == .blocked && !$0.isChild }
        defer { waiting = Set(blocked.map(\.id)); primed = true }
        guard primed else { return [] }              // already waiting when the app started: not news
        return blocked.filter { !waiting.contains($0.id) && $0.spaceID != focused }
    }
}

enum Strip {
    static let rowHeight: CGFloat = 28
    static let maxRows = 4
    static let seconds = 5.0
    static let font = NSFont.systemFont(ofSize: 12.5, weight: .medium)

    static func text(_ a: Agent) -> String { "\(a.space) needs you" }

    /// As narrow as its longest line, never wider than the panel.
    static func size(_ agents: [Agent]) -> CGSize {
        let rows = agents.prefix(maxRows).map(text) + (agents.count > maxRows ? ["and \(agents.count - maxRows) more"] : [])
        let widest = rows.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        return CGSize(width: min(Geometry.panelWidth, ceil(widest) + 2 * 14 + 8 + 7),
                      height: CGFloat(rows.count) * rowHeight + 8)
    }
}

struct NeedsYouStrip: View {
    @ObservedObject var store: Store

    var body: some View {
        let size = Strip.size(store.strip)
        VStack(spacing: 0) {
            ForEach(store.strip.prefix(Strip.maxRows), id: \.id) { a in
                Button { store.jump(to: a) } label: {
                    HStack(spacing: 7) {
                        Mark(state: .blocked, size: 8)
                        Text(Strip.text(a)).font(.system(size: 12.5, weight: .medium)).foregroundColor(Ink.primary).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14).frame(height: Strip.rowHeight).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if store.strip.count > Strip.maxRows {
                Text("and \(store.strip.count - Strip.maxRows) more").font(.system(size: 12.5)).foregroundColor(Ink.secondary)
                    .padding(.horizontal, 14).frame(maxWidth: .infinity, alignment: .leading).frame(height: Strip.rowHeight)
            }
        }
        .padding(.vertical, 4)
        .frame(width: size.width, height: size.height, alignment: .top)
        .background(PanelBackdrop(open: true))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
    }
}

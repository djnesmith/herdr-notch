import AppKit
import SwiftUI

// What Herdr reports: agents, grouped into workspaces, grouped by machine.

// MARK: - Model

enum AgentState: String, CaseIterable {
    case blocked, done, working, idle
    var rank: Int { Self.allCases.firstIndex(of: self)! }
    var color: Color {
        switch self {
        case .blocked: return Color(red: 0.93, green: 0.62, blue: 0.59)
        case .done: return Color(red: 0.55, green: 0.73, blue: 0.93)
        case .working: return Color(red: 0.85, green: 0.74, blue: 0.47)
        case .idle: return Color(white: 0.5)
        }
    }
    var label: String { self == .blocked ? "needs you" : rawValue }
}

struct Agent: Identifiable {
    let id: String          // address: "t8" on this Mac, "build-box/t89" on another machine
    let machine: String     // "" = this Mac
    let spaceID: String
    let space: String
    let app: String
    let state: AgentState
    let title: String
    let summary: String
    let cwd: String
    let isChild: Bool
    let parent: String?
    let statusMs: Double

    var appName: String {
        switch app {
        case "claude-code", "claude": return "Claude Code"
        case "codex": return "Codex"
        default: return app.prefix(1).uppercased() + app.dropFirst()
        }
    }
}

struct Workspace: Identifiable {
    let id: String
    let machine: String
    let name: String
    let agents: [Agent]     // most urgent first
    var top: Agent { agents[0] }
    var state: AgentState { top.state }
}

struct MachineGroup: Identifiable {
    let id: String
    let workspaces: [Workspace]
    var name: String { machineName(id) }
}

func machineName(_ id: String) -> String { id.isEmpty ? "This Mac" : id }

func ago(_ ms: Double) -> String {
    guard ms > 0 else { return "" }
    let s = max(0, Date().timeIntervalSince1970 - ms / 1000)
    if s < 60 { return "now" }
    if s < 3600 { return "\(Int(s / 60))m" }
    if s < 86400 { return "\(Int(s / 3600))h" }
    return "\(Int(s / 86400))d"
}

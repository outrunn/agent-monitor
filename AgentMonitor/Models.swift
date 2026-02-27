import Foundation
import SwiftUI

// MARK: - Project

struct Project: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var path: String
    var addedAt: Date

    init(name: String, path: String) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.addedAt = Date()
    }
}

// MARK: - Agent Session (Claude Code)

struct AgentSession: Identifiable {
    let id: String
    var sessionId: String? // Claude session ID from stream result
    var status: Status
    var prompt: String
    var startedAt: Date
    var lastActivity: Date
    var outputLines: [OutputLine] = []
    var costUSD: Double?

    init(prompt: String) {
        self.id = UUID().uuidString
        self.prompt = prompt
        self.status = .running
        self.startedAt = Date()
        self.lastActivity = Date()
    }

    var duration: String {
        let ref = status == .running ? Date() : lastActivity
        let elapsed = max(0, ref.timeIntervalSince(startedAt))
        let seconds = Int(elapsed)
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        let secs = seconds % 60
        return "\(minutes)m \(secs)s"
    }

    var task: String { prompt }

    var issue: String? {
        let pattern = #"#(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: prompt, range: NSRange(prompt.startIndex..., in: prompt)),
              let range = Range(match.range(at: 0), in: prompt) else { return nil }
        return String(prompt[range])
    }

    var command: String {
        let truncated = prompt.prefix(60)
        return "claude -p \"\(truncated)\(prompt.count > 60 ? "..." : "")\""
    }

    var lastAssistantMessage: String {
        outputLines.last(where: { $0.type == "assistant" })?.content ?? ""
    }

    var fullOutput: String {
        outputLines.map { line in
            switch line.type {
            case "assistant": return line.content
            case "tool_use": return "  > \(line.content)"
            case "error": return "ERROR: \(line.content)"
            case "system": return "--- \(line.content) ---"
            default: return line.content
            }
        }.joined(separator: "\n\n")
    }

    struct OutputLine: Identifiable {
        let id = UUID()
        let timestamp: Date
        let type: String // "assistant", "tool_use", "tool_result", "result", "error", "system"
        let content: String
    }

    enum Status: String, CaseIterable {
        case running
        case failed
        case completed

        var color: Color {
            switch self {
            case .running: return .green
            case .failed: return .red
            case .completed: return .blue
            }
        }

        var icon: String {
            switch self {
            case .running: return "play.circle.fill"
            case .failed: return "xmark.circle.fill"
            case .completed: return "checkmark.circle.fill"
            }
        }

        var cardBackground: Color {
            switch self {
            case .running: return Color.green.opacity(0.05)
            case .failed: return Color.red.opacity(0.05)
            case .completed: return Color.blue.opacity(0.05)
            }
        }

        var compactBackground: Color {
            switch self {
            case .running: return Color.green.opacity(0.08)
            case .failed: return Color.red.opacity(0.08)
            case .completed: return Color.blue.opacity(0.08)
            }
        }
    }
}

// MARK: - GitHub Models

struct GitHubMilestone: Identifiable, Codable {
    let number: Int
    let title: String
    let openIssues: Int
    let closedIssues: Int
    let dueOn: String?

    var id: Int { number }

    var progress: Double {
        let total = Double(openIssues + closedIssues)
        return total > 0 ? Double(closedIssues) / total : 0
    }

    enum CodingKeys: String, CodingKey {
        case number, title
        case openIssues = "open_issues"
        case closedIssues = "closed_issues"
        case dueOn = "due_on"
    }
}

struct GitHubIssue: Identifiable, Codable {
    let number: Int
    let title: String
    let state: String
    let milestone: GitHubIssueMilestone?

    var id: Int { number }

    struct GitHubIssueMilestone: Codable {
        let number: Int
        let title: String
    }
}

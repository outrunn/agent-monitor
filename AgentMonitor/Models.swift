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

struct AgentSession: Identifiable, Codable {
    let id: String
    var sessionId: String? // Claude session ID from stream result
    var status: Status
    var prompt: String
    var startedAt: Date
    var lastActivity: Date
    var outputLines: [OutputLine] = []
    var costUSD: Double?
    var projectId: UUID?
    var diffOutput: String?

    init(prompt: String, projectId: UUID? = nil) {
        self.id = UUID().uuidString
        self.prompt = prompt
        self.status = .running
        self.startedAt = Date()
        self.lastActivity = Date()
        self.projectId = projectId
    }

    var duration: String {
        let ref = (status == .running || status == .interrupted) ? Date() : lastActivity
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

    var issueNumber: Int? {
        let pattern = #"#(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: prompt, range: NSRange(prompt.startIndex..., in: prompt)),
              let range = Range(match.range(at: 1), in: prompt) else { return nil }
        return Int(prompt[range])
    }

    var issueTitle: String? {
        guard let range = prompt.range(of: "Title: ") else { return nil }
        let after = prompt[range.upperBound...]
        if let newline = after.firstIndex(of: "\n") {
            let title = String(after[..<newline]).trimmingCharacters(in: .whitespaces)
            return title.isEmpty ? nil : title
        }
        let title = String(after).trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? nil : title
    }

    var command: String {
        let truncated = prompt.prefix(60)
        return "claude -p \"\(truncated)\(prompt.count > 60 ? "..." : "")\""
    }

    var lastAssistantMessage: String {
        outputLines.last(where: { $0.type == "assistant" })?.content ?? ""
    }

    /// Extracts a pending question from the last assistant message if the agent
    /// finished and its final output looks like it's asking something.
    var pendingQuestion: String? {
        guard status != .running else { return nil }
        let msg = lastAssistantMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty else { return nil }

        // Check if the message ends with a question mark (possibly after whitespace/newlines)
        let lines = msg.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let lastLine = lines.last else { return nil }

        // Look for question marks in the last few lines
        let tail = lines.suffix(5).joined(separator: "\n")
        guard tail.contains("?") else { return nil }

        // Return the last paragraph that contains the question
        // Split on double newlines to get paragraphs
        let paragraphs = msg.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if let lastPara = paragraphs.last, lastPara.contains("?") {
            let trimmed = lastPara.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.count > 500 ? String(trimmed.suffix(500)) : trimmed
        }

        return lastLine.contains("?") ? lastLine.trimmingCharacters(in: .whitespaces) : nil
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

    struct OutputLine: Identifiable, Codable {
        let id: UUID
        let timestamp: Date
        let type: String // "assistant", "tool_use", "tool_result", "result", "error", "system"
        let content: String

        init(timestamp: Date, type: String, content: String) {
            self.id = UUID()
            self.timestamp = timestamp
            self.type = type
            self.content = content
        }

        init(id: UUID, timestamp: Date, type: String, content: String) {
            self.id = id
            self.timestamp = timestamp
            self.type = type
            self.content = content
        }
    }

    enum Status: String, CaseIterable, Codable {
        case running
        case failed
        case completed
        case interrupted

        var color: Color {
            switch self {
            case .running: return .green
            case .failed: return .red
            case .completed: return .blue
            case .interrupted: return .orange
            }
        }

        var icon: String {
            switch self {
            case .running: return "play.circle.fill"
            case .failed: return "xmark.circle.fill"
            case .completed: return "checkmark.circle.fill"
            case .interrupted: return "pause.circle.fill"
            }
        }

        var cardBackground: Color {
            switch self {
            case .running: return Color.green.opacity(0.05)
            case .failed: return Color.red.opacity(0.05)
            case .completed: return Color.blue.opacity(0.05)
            case .interrupted: return Color.orange.opacity(0.05)
            }
        }

        var compactBackground: Color {
            switch self {
            case .running: return Color.green.opacity(0.08)
            case .failed: return Color.red.opacity(0.08)
            case .completed: return Color.blue.opacity(0.08)
            case .interrupted: return Color.orange.opacity(0.08)
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

    var percentComplete: Int {
        Int((progress * 100).rounded())
    }

    var parsedDueDate: Date? {
        guard let dueOn = dueOn else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dueOn) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dueOn)
    }

    var relativeDueDate: String? {
        guard let date = parsedDueDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0
        if days < 0 { return "Overdue by \(abs(days))d" }
        if days == 0 { return "Due today" }
        if days == 1 { return "Due tomorrow" }
        return "Due in \(days) days"
    }

    var isOverdue: Bool {
        guard let date = parsedDueDate else { return false }
        return date < Date()
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
    let labels: [GitHubLabel]

    var id: Int { number }

    var isInProgress: Bool {
        labels.contains { $0.name.lowercased() == "in progress" }
    }

    init(number: Int, title: String, state: String, milestone: GitHubIssueMilestone?, labels: [GitHubLabel] = []) {
        self.number = number
        self.title = title
        self.state = state
        self.milestone = milestone
        self.labels = labels
    }

    struct GitHubIssueMilestone: Codable {
        let number: Int
        let title: String
    }
}

struct GitHubLabel: Codable {
    let name: String
}

// MARK: - AI Issue Design Models

struct DesignMessage: Identifiable, Codable {
    let id: UUID
    let role: String // "user" or "assistant"
    let content: String
    let timestamp: Date

    init(role: String, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }

    init(id: UUID, role: String, content: String, timestamp: Date) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

struct DesignConversation: Codable {
    var id: UUID
    var messages: [DesignMessage]
    var claudeSessionId: String?
    var createdAt: Date

    init() {
        self.id = UUID()
        self.messages = []
        self.claudeSessionId = nil
        self.createdAt = Date()
    }
}

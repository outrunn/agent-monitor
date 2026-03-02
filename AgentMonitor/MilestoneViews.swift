import SwiftUI

struct MilestoneCard: View {
    let milestone: GitHubMilestone
    let issues: [GitHubIssue]
    let agents: [AgentSession]
    let onAgentTap: (AgentSession) -> Void
    let onAssignAgent: (GitHubIssue) -> Void
    let onCloseIssue: (GitHubIssue) -> Void
    let onRetryAgent: (GitHubIssue) -> Void
    var onCloseAndNext: ((GitHubIssue) -> Void)?
    var onIssueTap: ((GitHubIssue) -> Void)?

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(milestone.title)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Spacer()

                    if let dueDate = milestone.relativeDueDate {
                        Text(dueDate)
                            .font(.caption)
                            .foregroundColor(milestone.isOverdue ? .red : .secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background((milestone.isOverdue ? Color.red : Color.secondary).opacity(0.1))
                            .cornerRadius(4)
                    }

                    Text("\(milestone.percentComplete)%")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(progressColor)

                    HStack(spacing: 4) {
                        Text("\(milestone.closedIssues)/\(milestone.openIssues + milestone.closedIssues)")
                            .font(.caption)

                        Circle()
                            .fill(progressColor)
                            .frame(width: 6, height: 6)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(progressColor.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            .buttonStyle(.plain)

            // Colored progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(progressColor)
                        .frame(width: max(0, geo.size.width * milestone.progress), height: 6)
                }
            }
            .frame(height: 6)

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(issues.sorted { $0.number < $1.number }) { issue in
                        IssueRow(
                            issue: issue,
                            agents: agents,
                            onAgentTap: onAgentTap,
                            onAssignAgent: onAssignAgent,
                            onCloseIssue: onCloseIssue,
                            onRetryAgent: onRetryAgent,
                            onCloseAndNext: onCloseAndNext,
                            onIssueTap: onIssueTap
                        )
                    }

                    if issues.isEmpty {
                        Text("No open issues")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private var progressColor: Color {
        if milestone.progress >= 0.7 { return .green }
        if milestone.progress >= 0.4 { return .orange }
        return .blue
    }
}

struct IssueRow: View {
    let issue: GitHubIssue
    let agents: [AgentSession]
    let onAgentTap: (AgentSession) -> Void
    let onAssignAgent: (GitHubIssue) -> Void
    let onCloseIssue: (GitHubIssue) -> Void
    let onRetryAgent: (GitHubIssue) -> Void
    var onCloseAndNext: ((GitHubIssue) -> Void)?
    var onIssueTap: ((GitHubIssue) -> Void)?

    @State private var isHovering = false

    var assignedAgents: [AgentSession] {
        agents.filter { $0.issue == "#\(issue.number)" }
    }

    var hasCompletedAgent: Bool {
        assignedAgents.contains { $0.status == .completed }
    }

    var hasRunningAgent: Bool {
        assignedAgents.contains { $0.status == .running }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Clickable issue number + title
            Button(action: { onIssueTap?(issue) }) {
                HStack(spacing: 8) {
                    Text("#\(issue.number)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.15))
                        .cornerRadius(4)

                    if issue.isInProgress {
                        Text("in progress")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(3)
                    }

                    Text(issue.title)
                        .font(.callout)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if !assignedAgents.isEmpty {
                HStack(spacing: 4) {
                    ForEach(assignedAgents) { agent in
                        Button(action: { onAgentTap(agent) }) {
                            HStack(spacing: 4) {
                                if agent.status == .running {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                        .frame(width: 8, height: 8)
                                } else {
                                    Image(systemName: agent.status.icon)
                                        .font(.caption2)
                                        .foregroundColor(agent.status.color)
                                }

                                Text(String(agent.id.prefix(6)))
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(agent.status.color.opacity(0.15))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Retry button
            if !assignedAgents.isEmpty && !hasRunningAgent {
                Button(action: { onRetryAgent(issue) }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                        Text("Retry")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            // Close Issue button
            if hasCompletedAgent {
                Button(action: { onCloseIssue(issue) }) {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle")
                            .font(.caption)
                        Text("Close")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                // Close & Next button
                if let onCloseAndNext = onCloseAndNext {
                    Button(action: { onCloseAndNext(issue) }) {
                        HStack(spacing: 3) {
                            Image(systemName: "forward.fill")
                                .font(.caption2)
                            Text("Close & Next")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.purple.opacity(0.15))
                        .foregroundColor(.purple)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Assign Agent button
            if !hasRunningAgent && (isHovering || assignedAgents.isEmpty) {
                Button(action: { onAssignAgent(issue) }) {
                    HStack(spacing: 3) {
                        Image(systemName: "play.fill")
                            .font(.caption2)
                        Text("Assign")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.15))
                    .foregroundColor(.purple)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(assignedAgents.isEmpty ? Color.clear : Color.green.opacity(0.03))
        .cornerRadius(6)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct UnassignedIssuesCard: View {
    let issues: [GitHubIssue]
    let agents: [AgentSession]
    let onAgentTap: (AgentSession) -> Void
    let onAssignAgent: (GitHubIssue) -> Void
    let onCloseIssue: (GitHubIssue) -> Void
    let onRetryAgent: (GitHubIssue) -> Void
    var onIssueTap: ((GitHubIssue) -> Void)?

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Unassigned Issues")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Spacer()

                    Text("\(issues.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(issues) { issue in
                        IssueRow(
                            issue: issue,
                            agents: agents,
                            onAgentTap: onAgentTap,
                            onAssignAgent: onAssignAgent,
                            onCloseIssue: onCloseIssue,
                            onRetryAgent: onRetryAgent,
                            onIssueTap: onIssueTap
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Issue Detail Sheet

struct IssueDetailSheet: View {
    let issue: GitHubIssue
    @ObservedObject var github: GitHubManager
    @Environment(\.dismiss) var dismiss

    @State private var title: String = ""
    @State private var issueBody: String = ""
    @State private var isLoadingBody = true
    @State private var newComment = ""
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("#\(issue.number)")
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.purple)

                        if issue.isInProgress {
                            Text("in progress")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(4)
                        }

                        if let ms = issue.milestone {
                            Text(ms.title)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }

                    if !issue.labels.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(issue.labels, id: \.name) { label in
                                Text(label.name)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.12))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: closeIssue) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle")
                                .font(.caption)
                            Text("Close Issue")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)

                    Button("Done") { dismiss() }
                        .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            if isLoadingBody {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading issue details...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Title (editable)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Title")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            TextField("Issue title", text: $title)
                                .font(.title3)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                        }

                        // Body (editable)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            TextEditor(text: $issueBody)
                                .font(.system(.body, design: .monospaced))
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .frame(minHeight: 200)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                        }

                        // Save button
                        HStack {
                            Spacer()
                            Button(action: saveChanges) {
                                HStack(spacing: 4) {
                                    if isSaving {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                            .frame(width: 12, height: 12)
                                    }
                                    Text("Save Changes")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                            .disabled(isSaving || (title == issue.title))
                        }

                        Divider()

                        // Add comment
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Add Comment")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            HStack(alignment: .top, spacing: 8) {
                                TextEditor(text: $newComment)
                                    .font(.body)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .frame(height: 80)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                    )
                                Button(action: addComment) {
                                    Image(systemName: "paperplane.fill")
                                        .font(.body)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.purple)
                                .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 700, height: 600)
        .onAppear { loadIssue() }
    }

    private func loadIssue() {
        title = issue.title
        github.fetchIssueBody(number: issue.number) { fetchedTitle, fetchedBody in
            if let t = fetchedTitle { title = t }
            issueBody = fetchedBody ?? ""
            isLoadingBody = false
        }
    }

    private func saveChanges() {
        isSaving = true
        let process = Process()
        configureProcess(process)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        var args = ["gh", "issue", "edit", "\(issue.number)"]
        if title != issue.title {
            args += ["--title", title]
        }
        args += ["--body", issueBody]
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: github.project.path)
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
                process.waitUntilExit()
                DispatchQueue.main.async {
                    isSaving = false
                    if process.terminationStatus == 0 {
                        github.refresh()
                    }
                }
            } catch {
                DispatchQueue.main.async { isSaving = false }
            }
        }
    }

    private func addComment() {
        let comment = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !comment.isEmpty else { return }
        newComment = ""
        github.addIssueComment(number: issue.number, comment: comment)
    }

    private func closeIssue() {
        github.closeIssue(number: issue.number, comment: "Closed via Agent Monitor.")
        dismiss()
    }
}

struct EmptyGitHubView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Issues or Milestones")
                .font(.title3)
                .foregroundColor(.secondary)

            Text("This repo has no open GitHub issues.\nMake sure gh CLI is authenticated and this is a GitHub repo.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

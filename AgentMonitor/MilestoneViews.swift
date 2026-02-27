import SwiftUI

struct MilestoneCard: View {
    let milestone: GitHubMilestone
    let issues: [GitHubIssue]
    let agents: [AgentSession]
    let onAgentTap: (AgentSession) -> Void

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

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * milestone.progress, height: 4)
                }
            }
            .frame(height: 4)

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(issues) { issue in
                        IssueRow(issue: issue, agents: agents, onAgentTap: onAgentTap)
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

    var assignedAgents: [AgentSession] {
        agents.filter { $0.issue == "#\(issue.number)" }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(issue.number)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.purple)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.purple.opacity(0.15))
                .cornerRadius(4)

            Text(issue.title)
                .font(.callout)
                .lineLimit(2)

            Spacer()

            if !assignedAgents.isEmpty {
                HStack(spacing: 4) {
                    ForEach(assignedAgents) { agent in
                        Button(action: { onAgentTap(agent) }) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(agent.status.color)
                                    .frame(width: 6, height: 6)

                                Text(agent.id)
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
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(assignedAgents.isEmpty ? Color.clear : Color.green.opacity(0.03))
        .cornerRadius(6)
    }
}

struct UnassignedIssuesCard: View {
    let issues: [GitHubIssue]
    let agents: [AgentSession]
    let onAgentTap: (AgentSession) -> Void

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
                        IssueRow(issue: issue, agents: agents, onAgentTap: onAgentTap)
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

struct EmptyGitHubView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Loading GitHub data...")
                .font(.title3)
                .foregroundColor(.secondary)

            Text("Make sure gh CLI is configured")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

import SwiftUI

struct IssuesTabView: View {
    @ObservedObject var monitor: AgentMonitor
    @ObservedObject var github: GitHubManager
    let onAgentTap: (AgentSession) -> Void

    @State private var assigningIssue: Int?
    @State private var showingIssuePicker = false
    @State private var closingIssue: GitHubIssue?
    @State private var selectedIssue: GitHubIssue?
    @State private var showingIssueDetail = false
    @State private var issueViewMode = 0  // 0 = By Milestone, 1 = All Issues

    private var openCount: Int { github.issues.count }
    private var inProgressCount: Int { github.issues.filter { $0.isInProgress }.count }
    private var totalCount: Int { openCount + github.closedCount }
    private var overallProgress: Double {
        totalCount > 0 ? Double(github.closedCount) / Double(totalCount) : 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Stats bar
            HStack(spacing: 0) {
                statPill(
                    icon: "circle.fill",
                    value: "\(openCount)",
                    label: "Open",
                    color: .green
                )

                Divider().frame(height: 24)

                statPill(
                    icon: "checkmark.circle.fill",
                    value: "\(github.closedCount)",
                    label: "Closed",
                    color: .purple
                )

                Divider().frame(height: 24)

                statPill(
                    icon: "bolt.fill",
                    value: "\(inProgressCount)",
                    label: "In Progress",
                    color: .orange
                )

                Divider().frame(height: 24)

                Picker("", selection: $issueViewMode) {
                    Text("By Milestone").tag(0)
                    Text("All Issues").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Spacer()

                // Overall progress
                HStack(spacing: 8) {
                    Text("\(Int(overallProgress * 100))%")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.secondary.opacity(0.15))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.purple)
                                .frame(width: max(0, geo.size.width * overallProgress))
                        }
                    }
                    .frame(width: 80, height: 4)
                }

                Divider().frame(height: 24)

                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                    Text(timeAgo(github.lastUpdate))
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))

            Divider()

            HStack(spacing: 0) {
                // Left: Milestones & Issues
                ScrollView {
                    VStack(spacing: 16) {
                        // Error banner
                        if let error = github.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Dismiss") {
                                    github.errorMessage = nil
                                }
                                .font(.caption)
                                .buttonStyle(.borderless)
                            }
                            .padding(10)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }

                        if github.milestones.isEmpty && github.issues.isEmpty && !github.isLoading {
                            EmptyGitHubView()
                        } else if issueViewMode == 0 {
                            // By Milestone view
                            ForEach(github.milestones) { milestone in
                                MilestoneCard(
                                    milestone: milestone,
                                    issues: github.issuesForMilestone(milestone.number),
                                    agents: monitor.sessions,
                                    onAgentTap: onAgentTap,
                                    onAssignAgent: assignAgent,
                                    onCloseIssue: closeIssue,
                                    onRetryAgent: retryAgent,
                                    onCloseAndNext: closeAndNext,
                                    onIssueTap: showIssueDetail
                                )
                            }

                            let unassignedIssues = github.issuesWithoutMilestone()
                            if !unassignedIssues.isEmpty {
                                UnassignedIssuesCard(
                                    issues: unassignedIssues,
                                    agents: monitor.sessions,
                                    onAgentTap: onAgentTap,
                                    onAssignAgent: assignAgent,
                                    onCloseIssue: closeIssue,
                                    onRetryAgent: retryAgent,
                                    onIssueTap: showIssueDetail
                                )
                            }
                        } else {
                            // All Issues view (flat list)
                            ForEach(github.issues.sorted { $0.number < $1.number }) { issue in
                                IssueRow(
                                    issue: issue,
                                    agents: monitor.sessions,
                                    onAgentTap: onAgentTap,
                                    onAssignAgent: assignAgent,
                                    onCloseIssue: closeIssue,
                                    onRetryAgent: retryAgent,
                                    onCloseAndNext: closeAndNext,
                                    onIssueTap: showIssueDetail
                                )
                            }
                        }
                    }
                    .padding()
                }

            Divider()

            // Right: Active Agents (compact)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Active Agents")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(monitor.sessions.filter { $0.status == .running }.count) running")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(monitor.sessions) { session in
                            CompactAgentCard(session: session, onTap: { onAgentTap(session) })
                        }

                        if monitor.sessions.isEmpty && !monitor.isLoading {
                            VStack(spacing: 12) {
                                Image(systemName: "moon.zzz")
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary)
                                Text("No active agents")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .frame(width: 300)
        } // HStack
        } // VStack (outer with stats bar)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingIssuePicker) {
            IssuePickerSheet(
                github: github,
                closedIssue: closingIssue,
                onPick: { nextIssue in
                    showingIssuePicker = false
                    assignAgent(nextIssue)
                },
                onCancel: {
                    showingIssuePicker = false
                }
            )
        }
        .sheet(isPresented: $showingIssueDetail) {
            if let issue = selectedIssue {
                IssueDetailSheet(issue: issue, github: github)
            }
        }
    }

    // MARK: - Show Issue Detail

    private func showIssueDetail(_ issue: GitHubIssue) {
        selectedIssue = issue
        showingIssueDetail = true
    }

    // MARK: - Stat Pill

    private func statPill(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(color)
            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }

    // MARK: - Assign Agent to Issue

    private func assignAgent(_ issue: GitHubIssue) {
        assigningIssue = issue.number
        github.addInProgressLabel(number: issue.number)
        github.fetchIssueBody(number: issue.number) { title, body in
            assigningIssue = nil
            let issueTitle = title ?? issue.title
            let issueBody = body ?? ""

            let prompt = """
            Work on GitHub issue #\(issue.number) in this repository.

            Title: \(issueTitle)
            Description: \(issueBody)

            Read the codebase, implement the fix, and verify it works.
            """

            monitor.launchAgent(prompt: prompt)
        }
    }

    // MARK: - Retry Agent on Issue

    private func retryAgent(_ issue: GitHubIssue) {
        if let agent = monitor.sessions.first(where: {
            $0.issue == "#\(issue.number)" && $0.sessionId != nil && $0.status != .running
        }) {
            monitor.sendFollowUp(
                sessionId: agent.id,
                prompt: "The previous attempt didn't fully resolve issue #\(issue.number). Please review what was done, check for any errors or missed requirements, and try again to complete the task."
            )
        } else {
            assignAgent(issue)
        }
    }

    // MARK: - Close Issue

    private func closeIssue(_ issue: GitHubIssue) {
        let completedAgent = monitor.sessions.first {
            $0.issue == "#\(issue.number)" && $0.status == .completed
        }

        var comment = "Closed via Agent Monitor."
        if let agent = completedAgent, !agent.lastAssistantMessage.isEmpty {
            let summary = String(agent.lastAssistantMessage.prefix(500))
            comment = "Resolved by automated agent.\n\nAgent summary:\n\(summary)"
        }

        github.closeIssue(number: issue.number, comment: comment)
    }

    // MARK: - Close & Next

    private func closeAndNext(_ issue: GitHubIssue) {
        let completedAgent = monitor.sessions.first {
            $0.issue == "#\(issue.number)" && $0.status == .completed
        }

        var comment = "Closed via Agent Monitor."
        if let agent = completedAgent, !agent.lastAssistantMessage.isEmpty {
            let summary = String(agent.lastAssistantMessage.prefix(500))
            comment = "Resolved by automated agent.\n\nAgent summary:\n\(summary)"
        }

        github.closeIssue(number: issue.number, comment: comment) { success in
            if success {
                closingIssue = issue
                showingIssuePicker = true
            }
        }
    }
}

// MARK: - Issue Picker Sheet

struct IssuePickerSheet: View {
    @ObservedObject var github: GitHubManager
    let closedIssue: GitHubIssue?
    let onPick: (GitHubIssue) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pick Next Issue")
                        .font(.title3)
                        .fontWeight(.bold)

                    if let closed = closedIssue {
                        Text("Closed #\(closed.number) — select the next issue to work on")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button("Cancel") { onCancel() }
                    .buttonStyle(.bordered)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // Group by milestone
                    ForEach(github.milestones) { milestone in
                        let milestoneIssues = github.issuesForMilestone(milestone.number)
                            .filter { $0.number != closedIssue?.number }
                        if !milestoneIssues.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(milestone.title)
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(milestone.percentComplete)%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                ForEach(milestoneIssues) { issue in
                                    issuePickerRow(issue: issue)
                                }
                            }
                        }
                    }

                    // Unassigned issues
                    let unassigned = github.issuesWithoutMilestone()
                        .filter { $0.number != closedIssue?.number }
                    if !unassigned.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No Milestone")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            ForEach(unassigned) { issue in
                                issuePickerRow(issue: issue)
                            }
                        }
                    }

                    if github.issues.filter({ $0.number != closedIssue?.number }).isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.green)
                            Text("No more open issues!")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 500)
    }

    @ViewBuilder
    private func issuePickerRow(issue: GitHubIssue) -> some View {
        let busy = issue.isInProgress
        Button(action: { if !busy { onPick(issue) } }) {
            HStack(spacing: 12) {
                Text("#\(issue.number)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(busy ? .secondary : .purple)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((busy ? Color.secondary : Color.purple).opacity(0.15))
                    .cornerRadius(4)

                if busy {
                    Text("in progress")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(3)
                }

                Text(issue.title)
                    .font(.body)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(busy ? .secondary : .primary)

                Spacer()

                if busy {
                    Image(systemName: "hourglass")
                        .foregroundColor(.orange)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.purple)
                }
            }
            .padding(10)
            .background(busy ? Color.secondary.opacity(0.03) : Color.purple.opacity(0.03))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }
}

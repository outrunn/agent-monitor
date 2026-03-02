import SwiftUI

struct ProjectView: View {
    let project: Project
    let onBack: () -> Void

    @StateObject private var monitor: AgentMonitor
    @StateObject private var github: GitHubManager
    @StateObject private var designManager: IssueDesignManager
    @State private var selectedTab = 0
    @State private var selectedSessionId: String?
    @State private var showingLog = false
    @State private var showingIssuePicker = false
    @State private var chainingSession: AgentSession?

    init(project: Project, onBack: @escaping () -> Void) {
        self.project = project
        self.onBack = onBack
        _monitor = StateObject(wrappedValue: AgentMonitor(project: project))
        _github = StateObject(wrappedValue: GitHubManager(project: project))
        _designManager = StateObject(wrappedValue: IssueDesignManager(project: project))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Projects")
                    }
                    .font(.caption)
                }
                .buttonStyle(.borderless)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 24))
                    .foregroundColor(.purple)
                    .padding(.leading, 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Agent Monitor")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(project.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Picker("", selection: $selectedTab) {
                    Text("Agents").tag(0)
                    Text("Issues").tag(1)
                    Text("Costs").tag(2)
                    Text("Design").tag(3)
                }
                .pickerStyle(.segmented)
                .frame(width: 400)

                Spacer().frame(width: 16)

                HStack(spacing: 8) {
                    let runningCount = monitor.sessions.filter { $0.status == .running }.count
                    if runningCount > 0 {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("\(runningCount) running")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    StatusIndicator(isLoading: monitor.isLoading || github.isLoading)

                    Text(timeAgo(monitor.lastUpdate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button(action: {
                    monitor.refresh()
                    github.refresh()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Tab Content
            if selectedTab == 0 {
                AgentsTabView(
                    monitor: monitor,
                    onAgentTap: showAgentLog,
                    onCloseAndNext: { session in
                        handleCloseAndNext(session)
                    },
                    onCloseIssue: { session in
                        handleCloseIssue(session)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selectedTab == 1 {
                IssuesTabView(monitor: monitor, github: github, onAgentTap: showAgentLog)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selectedTab == 2 {
                CostDashboardView(monitor: monitor, github: github)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selectedTab == 3 {
                IssueDesignView(designManager: designManager, github: github)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            monitor.onSessionFinished = { session in
                // Remove "in progress" label when agent completes or fails
                if let num = session.issueNumber {
                    github.removeInProgressLabel(number: num)
                }
            }
        }
        .sheet(isPresented: $showingLog) {
            if let sessionId = selectedSessionId {
                LogView(sessionId: sessionId, monitor: monitor)
            }
        }
        .sheet(isPresented: $showingIssuePicker) {
            IssuePickerSheet(
                github: github,
                closedIssue: chainingSession.flatMap { session in
                    session.issueNumber.flatMap { num in
                        GitHubIssue(number: num, title: "", state: "OPEN", milestone: nil)
                    }
                },
                onPick: { nextIssue in
                    showingIssuePicker = false
                    launchAgentForIssue(nextIssue)
                },
                onCancel: {
                    showingIssuePicker = false
                }
            )
        }
    }

    private func showAgentLog(_ session: AgentSession) {
        selectedSessionId = session.id
        showingLog = true
    }

    private func handleCloseIssue(_ session: AgentSession) {
        guard let issueNumber = session.issueNumber else { return }

        var comment = "Closed via Agent Monitor."
        if !session.lastAssistantMessage.isEmpty {
            let summary = String(session.lastAssistantMessage.prefix(500))
            comment = "Resolved by automated agent.\n\nAgent summary:\n\(summary)"
        }

        github.closeIssue(number: issueNumber, comment: comment)
    }

    private func handleCloseAndNext(_ session: AgentSession) {
        guard let issueNumber = session.issueNumber else { return }

        var comment = "Closed via Agent Monitor."
        if !session.lastAssistantMessage.isEmpty {
            let summary = String(session.lastAssistantMessage.prefix(500))
            comment = "Resolved by automated agent.\n\nAgent summary:\n\(summary)"
        }

        github.closeIssue(number: issueNumber, comment: comment) { success in
            if success {
                chainingSession = session
                showingIssuePicker = true
            }
        }
    }

    private func launchAgentForIssue(_ issue: GitHubIssue) {
        github.addInProgressLabel(number: issue.number)
        github.fetchIssueBody(number: issue.number) { title, body in
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
}

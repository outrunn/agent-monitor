import SwiftUI

struct ProjectView: View {
    let project: Project
    let onBack: () -> Void

    @StateObject private var monitor: AgentMonitor
    @StateObject private var github: GitHubManager
    @State private var selectedTab = 0
    @State private var selectedSessionId: String?
    @State private var showingLog = false

    init(project: Project, onBack: @escaping () -> Void) {
        self.project = project
        self.onBack = onBack
        _monitor = StateObject(wrappedValue: AgentMonitor(project: project))
        _github = StateObject(wrappedValue: GitHubManager(project: project))
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
                    Text("Issues & Milestones").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 240)

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
                AgentsTabView(monitor: monitor, onAgentTap: showAgentLog)
            } else {
                IssuesTabView(monitor: monitor, github: github, onAgentTap: showAgentLog)
            }
        }
        .onAppear {
            github.refresh()
        }
        .sheet(isPresented: $showingLog) {
            if let sessionId = selectedSessionId {
                LogView(sessionId: sessionId, monitor: monitor)
            }
        }
    }

    private func showAgentLog(_ session: AgentSession) {
        selectedSessionId = session.id
        showingLog = true
    }
}

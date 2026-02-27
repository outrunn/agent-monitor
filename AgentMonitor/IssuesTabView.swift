import SwiftUI

struct IssuesTabView: View {
    @ObservedObject var monitor: AgentMonitor
    @ObservedObject var github: GitHubManager
    let onAgentTap: (AgentSession) -> Void

    var body: some View {
        HSplitView {
            // Left: Milestones & Issues
            ScrollView {
                VStack(spacing: 16) {
                    if github.milestones.isEmpty && !github.isLoading {
                        EmptyGitHubView()
                    } else {
                        ForEach(github.milestones) { milestone in
                            MilestoneCard(
                                milestone: milestone,
                                issues: github.issuesForMilestone(milestone.number),
                                agents: monitor.sessions,
                                onAgentTap: onAgentTap
                            )
                        }

                        let unassignedIssues = github.issuesWithoutMilestone()
                        if !unassignedIssues.isEmpty {
                            UnassignedIssuesCard(
                                issues: unassignedIssues,
                                agents: monitor.sessions,
                                onAgentTap: onAgentTap
                            )
                        }
                    }
                }
                .padding()
            }
            .frame(minWidth: 400)

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
            .frame(minWidth: 300)
        }
    }
}

import SwiftUI

struct CostDashboardView: View {
    @ObservedObject var monitor: AgentMonitor
    @ObservedObject var github: GitHubManager

    private var sessionsWithCost: [AgentSession] {
        monitor.sessions.filter { $0.costUSD != nil }
    }

    private var totalCost: Double {
        sessionsWithCost.compactMap(\.costUSD).reduce(0, +)
    }

    private var averageCost: Double {
        sessionsWithCost.isEmpty ? 0 : totalCost / Double(sessionsWithCost.count)
    }

    var body: some View {
        if sessionsWithCost.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary.opacity(0.4))
                Text("No Cost Data Yet")
                    .font(.title3)
                    .fontWeight(.medium)
                Text("Cost information will appear here after agents finish running.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary row
                    HStack(spacing: 16) {
                        StatPill(title: "Total Spend", value: String(format: "$%.4f", totalCost), icon: "dollarsign.circle.fill", color: .green)
                        StatPill(title: "Sessions", value: "\(sessionsWithCost.count)", icon: "number.circle.fill", color: .blue)
                        StatPill(title: "Avg / Session", value: String(format: "$%.4f", averageCost), icon: "chart.bar.fill", color: .purple)
                    }
                    .padding(.horizontal)

                    // Milestone breakdown
                    if !github.milestones.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Cost by Milestone")
                                .font(.headline)
                                .padding(.horizontal)

                            let milestoneData = milestoneCosts()
                            let maxCost = milestoneData.map(\.cost).max() ?? 1

                            ForEach(milestoneData, id: \.milestone.number) { item in
                                HStack(spacing: 12) {
                                    Text(item.milestone.title)
                                        .font(.caption)
                                        .frame(width: 140, alignment: .trailing)
                                        .lineLimit(1)

                                    GeometryReader { geo in
                                        let width = maxCost > 0
                                            ? CGFloat(item.cost / maxCost) * geo.size.width
                                            : 0
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.purple.opacity(0.6))
                                            .frame(width: max(width, 2), height: 20)
                                    }
                                    .frame(height: 20)

                                    Text(String(format: "$%.4f", item.cost))
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .frame(width: 80, alignment: .trailing)
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }

                    // Session table
                    VStack(alignment: .leading, spacing: 8) {
                        Text("All Sessions")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(sessionsWithCost.sorted(by: { ($0.costUSD ?? 0) > ($1.costUSD ?? 0) })) { session in
                            HStack(spacing: 10) {
                                Image(systemName: session.status.icon)
                                    .foregroundColor(session.status.color)
                                    .frame(width: 20)

                                if let issue = session.issue {
                                    Text(issue)
                                        .font(.system(.caption, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.purple.opacity(0.15))
                                        .cornerRadius(4)
                                }

                                Text(session.issueTitle ?? String(session.prompt.prefix(60)))
                                    .font(.caption)
                                    .lineLimit(1)

                                Spacer()

                                Text(session.duration)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 60, alignment: .trailing)

                                Text(String(format: "$%.4f", session.costUSD ?? 0))
                                    .font(.system(.caption, design: .monospaced))
                                    .fontWeight(.medium)
                                    .frame(width: 80, alignment: .trailing)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                            .cornerRadius(6)
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
        }
    }

    private struct MilestoneCost {
        let milestone: GitHubMilestone
        let cost: Double
    }

    private func milestoneCosts() -> [MilestoneCost] {
        github.milestones.compactMap { milestone in
            let issueNumbers = Set(github.issuesForMilestone(milestone.number).map(\.number))
            let cost = monitor.sessions
                .filter { session in
                    guard let num = session.issueNumber else { return false }
                    return issueNumbers.contains(num)
                }
                .compactMap(\.costUSD)
                .reduce(0, +)
            guard cost > 0 else { return nil }
            return MilestoneCost(milestone: milestone, cost: cost)
        }
        .sorted { $0.cost > $1.cost }
    }
}

private struct StatPill: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08))
        .cornerRadius(10)
    }
}

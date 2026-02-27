import SwiftUI

struct AgentCard: View {
    let session: AgentSession
    let onTap: () -> Void
    var onStop: (() -> Void)?

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                VStack {
                    Image(systemName: session.status.icon)
                        .font(.system(size: 32))
                        .foregroundColor(session.status.color)
                        .opacity(session.status == .running ? 0.8 : 1.0)

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        if let sid = session.sessionId {
                            Text(String(sid.prefix(8)))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        if let issue = session.issue {
                            Text(issue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.2))
                                .cornerRadius(4)
                        }

                        Spacer()

                        if let cost = session.costUSD {
                            Text(String(format: "$%.4f", cost))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Text(session.duration)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }

                    Text(session.task)
                        .font(.body)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if !session.lastAssistantMessage.isEmpty {
                        Text(session.lastAssistantMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        Text(session.status.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(session.status.color)

                        if session.status == .running {
                            if let lastTool = session.outputLines.last(where: { $0.type == "tool_use" }) {
                                Text(lastTool.content)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                Spacer()

                VStack(spacing: 8) {
                    if let onStop = onStop, session.status == .running {
                        Button(action: {
                            onStop()
                        }) {
                            Image(systemName: "stop.circle.fill")
                                .font(.title3)
                                .foregroundColor(.red.opacity(0.7))
                        }
                        .buttonStyle(.borderless)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(session.status.cardBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

struct CompactAgentCard: View {
    let session: AgentSession
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Circle()
                    .fill(session.status.color)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if let sid = session.sessionId {
                            Text(String(sid.prefix(8)))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        if let issue = session.issue {
                            Text(issue)
                                .font(.caption2)
                                .foregroundColor(.purple)
                        }
                    }

                    Text(session.task)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(session.duration)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(session.status.compactBackground)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

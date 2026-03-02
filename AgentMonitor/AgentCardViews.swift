import SwiftUI

struct AgentCard: View {
    let session: AgentSession
    let onTap: () -> Void
    var onStop: (() -> Void)?
    var onFollowUp: ((String) -> Void)?
    var onDismiss: (() -> Void)?
    var onCloseIssue: (() -> Void)?
    var onCloseAndNext: (() -> Void)?

    @State private var followUpText = ""
    @State private var showFollowUp = false
    @State private var isCompact = false

    var body: some View {
        if isCompact {
            compactDoneView
        } else {
            fullCardView
        }
    }

    // MARK: - Compact Done View

    private var compactDoneView: some View {
        Button(action: { isCompact = false }) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundColor(.green)

                if let issue = session.issue {
                    Text(issue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                }

                Text(session.issueTitle ?? session.task)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()

                Text(session.duration)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if let cost = session.costUSD {
                    Text(String(format: "$%.4f", cost))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(Color.green.opacity(0.05))
        .cornerRadius(8)
    }

    // MARK: - Full Card View

    private var fullCardView: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                                    .fontWeight(.semibold)
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

                        if let title = session.issueTitle {
                            Text(title)
                                .font(.body)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        } else {
                            Text(session.task)
                                .font(.body)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }

                        if session.pendingQuestion == nil && !session.lastAssistantMessage.isEmpty {
                            Text(session.lastAssistantMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        HStack(spacing: 8) {
                            if session.pendingQuestion != nil {
                                HStack(spacing: 4) {
                                    Image(systemName: "questionmark.circle.fill")
                                        .font(.caption)
                                    Text("Awaiting Response")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.yellow)
                            } else {
                                Text(session.status.rawValue.capitalized)
                                    .font(.caption)
                                    .foregroundColor(session.status.color)
                            }

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

                        if session.status != .running, let onDismiss = onDismiss {
                            Button(action: { onDismiss() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                            .buttonStyle(.borderless)
                            .help("Dismiss agent")
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            }
            .buttonStyle(.plain)

            // Pending question banner
            if let question = session.pendingQuestion, session.sessionId != nil {
                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "questionmark.bubble.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Text("Agent is asking:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.yellow)
                    }

                    Text(question)
                        .font(.callout)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(8)

                    HStack(spacing: 8) {
                        TextField("Type your response...", text: $followUpText)
                            .textFieldStyle(.roundedBorder)
                            .font(.callout)
                            .onSubmit { sendFollowUp() }

                        Button("Respond") { sendFollowUp() }
                            .buttonStyle(.borderedProminent)
                            .tint(.yellow)
                            .disabled(followUpText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding()
                .background(Color.yellow.opacity(0.08))
            }

            // Inline follow-up controls for completed/failed/interrupted agents
            if session.status != .running && session.sessionId != nil {
                Divider()
                    .padding(.horizontal)

                if showFollowUp && session.pendingQuestion == nil {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("Follow-up prompt...", text: $followUpText)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                            .onSubmit { sendFollowUp() }

                        Button("Send") { sendFollowUp() }
                            .font(.caption)
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                            .disabled(followUpText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button(action: { showFollowUp = false }) {
                            Image(systemName: "xmark")
                                .font(.caption2)
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                } else {
                    HStack(spacing: 8) {
                        if session.pendingQuestion == nil {
                            Button(action: { showFollowUp = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.turn.down.right")
                                        .font(.caption2)
                                    Text("Follow Up")
                                        .font(.caption)
                                }
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.purple)
                        }

                        Button(action: { retryAgent() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption2)
                                Text("Retry")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.orange)

                        if session.status == .completed, session.issue != nil {
                            if let onCloseIssue = onCloseIssue {
                                Button(action: { onCloseIssue() }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle")
                                            .font(.caption2)
                                        Text("Close Issue")
                                            .font(.caption)
                                    }
                                }
                                .buttonStyle(.borderless)
                                .foregroundColor(.green)
                            }

                            if let onCloseAndNext = onCloseAndNext {
                                Button(action: { onCloseAndNext() }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "forward.fill")
                                            .font(.caption2)
                                        Text("Close & Next")
                                            .font(.caption)
                                    }
                                }
                                .buttonStyle(.borderless)
                                .foregroundColor(.purple)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(session.status.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private func sendFollowUp() {
        let prompt = followUpText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        onFollowUp?(prompt)
        followUpText = ""
        showFollowUp = false
    }

    private func retryAgent() {
        onFollowUp?("The previous attempt didn't fully work. Please review what was done, check for any errors, and try again to complete the task.")
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
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                        }
                    }

                    Text(session.issueTitle ?? session.task)
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

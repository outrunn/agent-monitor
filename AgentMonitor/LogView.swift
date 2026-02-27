import SwiftUI

struct LogView: View {
    let sessionId: String
    @ObservedObject var monitor: AgentMonitor
    @Environment(\.dismiss) var dismiss
    @State private var followUpPrompt = ""

    private var session: AgentSession? {
        monitor.sessions.first { $0.id == sessionId }
    }

    var body: some View {
        if let session = session {
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: session.status.icon)
                                .foregroundColor(session.status.color)

                            if let sid = session.sessionId {
                                Text(String(sid.prefix(12)))
                                    .font(.system(.title3, design: .monospaced))
                                    .fontWeight(.bold)
                            } else {
                                Text("Agent")
                                    .font(.title3)
                                    .fontWeight(.bold)
                            }

                            Text(session.status.rawValue.capitalized)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(session.status.color.opacity(0.15))
                                .foregroundColor(session.status.color)
                                .cornerRadius(6)

                            Text(session.duration)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(session.prompt)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    if let cost = session.costUSD {
                        Text(String(format: "$%.4f", cost))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                    }

                    if session.status == .running {
                        Button(action: { monitor.stopAgent(sessionId: sessionId) }) {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }

                    Button("Done") {
                        dismiss()
                    }
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                // Output
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(session.outputLines) { line in
                                OutputLineView(line: line)
                                    .id(line.id)
                            }

                            if session.outputLines.isEmpty {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 12) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Waiting for output...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.top, 40)
                                    Spacer()
                                }
                            }

                            // Invisible anchor at bottom
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding()
                    }
                    .background(Color(NSColor.textBackgroundColor))
                    .onChange(of: session.outputLines.count) { _ in
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .onAppear {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }

                // Follow-up prompt
                if session.sessionId != nil && session.status != .running {
                    Divider()
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.turn.down.right")
                            .foregroundColor(.secondary)

                        TextField("Send follow-up prompt...", text: $followUpPrompt)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { sendFollowUp() }

                        Button("Send") { sendFollowUp() }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                            .disabled(followUpPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding()
                }
            }
            .frame(width: 900, height: 650)
        } else {
            VStack {
                Text("Session not found")
                    .foregroundColor(.secondary)
                Button("Done") { dismiss() }
            }
            .frame(width: 400, height: 200)
        }
    }

    private func sendFollowUp() {
        let prompt = followUpPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        monitor.sendFollowUp(sessionId: sessionId, prompt: prompt)
        followUpPrompt = ""
    }
}

struct OutputLineView: View {
    let line: AgentSession.OutputLine

    var body: some View {
        switch line.type {
        case "assistant":
            Text(line.content)
                .font(.system(.body, design: .default))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)

        case "tool_use":
            HStack(spacing: 6) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.caption2)
                    .foregroundColor(.orange)
                Text(line.content)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.orange)
                    .lineLimit(1)
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 8)
            .background(Color.orange.opacity(0.05))
            .cornerRadius(4)

        case "error":
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundColor(.red)
                Text(line.content)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.red)
                    .textSelection(.enabled)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color.red.opacity(0.05))
            .cornerRadius(4)

        case "system":
            HStack {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
                Text(line.content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.vertical, 8)

        default:
            Text(line.content)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

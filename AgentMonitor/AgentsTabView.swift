import SwiftUI

struct AgentsTabView: View {
    @ObservedObject var monitor: AgentMonitor
    let onAgentTap: (AgentSession) -> Void
    var onCloseAndNext: ((AgentSession) -> Void)?
    var onCloseIssue: ((AgentSession) -> Void)?

    @State private var showingNewAgent = false
    @State private var newPrompt = ""
    @FocusState private var promptFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // New agent input area
            if showingNewAgent {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "terminal.fill")
                            .foregroundColor(.purple)
                        Text("Launch New Agent")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingNewAgent = false
                                newPrompt = ""
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }

                    TextEditor(text: $newPrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 80)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                        )
                        .focused($promptFocused)

                    HStack {
                        Image(systemName: "folder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(monitor.project.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Text("Runs with --dangerously-skip-permissions")
                            .font(.caption2)
                            .foregroundColor(.orange)

                        Button("Launch") {
                            launchAgent()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .disabled(newPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .keyboardShortcut(.return, modifiers: .command)
                    }
                }
                .padding()
                .background(Color.purple.opacity(0.03))

                Divider()
            }

            ScrollView {
                LazyVStack(spacing: 12) {
                    // New Agent button
                    if !showingNewAgent {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingNewAgent = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                promptFocused = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.purple)
                                Text("New Agent")
                                    .font(.headline)
                                    .foregroundColor(.purple)
                                Spacer()
                                Text("Cmd+N")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.purple.opacity(0.05))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.purple.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [6]))
                            )
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut("n", modifiers: .command)
                    }

                    ForEach(monitor.sessions) { session in
                        AgentCard(
                            session: session,
                            onTap: { onAgentTap(session) },
                            onStop: session.status == .running ? { monitor.stopAgent(sessionId: session.id) } : nil,
                            onFollowUp: { prompt in
                                monitor.sendFollowUp(sessionId: session.id, prompt: prompt)
                            },
                            onDismiss: session.status != .running ? {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    monitor.removeSession(id: session.id)
                                }
                            } : nil,
                            onCloseIssue: session.issue != nil && session.status == .completed ? {
                                onCloseIssue?(session)
                                removeAndShowPrompt(session)
                            } : nil,
                            onCloseAndNext: session.issue != nil && session.status == .completed ? {
                                onCloseAndNext?(session)
                                removeAndShowPrompt(session)
                            } : nil
                        )
                    }

                    if monitor.sessions.isEmpty && !showingNewAgent {
                        VStack(spacing: 16) {
                            Image(systemName: "terminal")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)

                            Text("No agents running")
                                .font(.title3)
                                .foregroundColor(.secondary)

                            Text("Launch a Claude Code agent to get started")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                }
                .padding()
            }
        }
    }

    private func launchAgent() {
        let prompt = newPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        monitor.launchAgent(prompt: prompt)
        newPrompt = ""
        withAnimation(.easeInOut(duration: 0.2)) {
            showingNewAgent = false
        }
    }

    private func removeAndShowPrompt(_ session: AgentSession) {
        withAnimation(.easeInOut(duration: 0.2)) {
            monitor.removeSession(id: session.id)
            showingNewAgent = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            promptFocused = true
        }
    }
}

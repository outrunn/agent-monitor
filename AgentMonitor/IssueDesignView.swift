import SwiftUI

struct IssueDesignView: View {
    @ObservedObject var designManager: IssueDesignManager
    @ObservedObject var github: GitHubManager
    @State private var inputText = ""
    @State private var createdIssues: Set<String> = []

    var body: some View {
        HSplitView {
            // Left: Chat
            VStack(spacing: 0) {
                HStack {
                    Text("AI Issue Designer")
                        .font(.headline)
                    Spacer()
                    Button(action: { designManager.startNewConversation() }) {
                        Label("New Chat", systemImage: "plus.bubble")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
                .padding()

                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(designManager.conversation.messages) { msg in
                                ChatBubble(message: msg)
                                    .id(msg.id)
                            }

                            if designManager.isThinking {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                    Text("Thinking...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                                .id("thinking")
                            }

                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding()
                    }
                    .onChange(of: designManager.conversation.messages.count) { _ in
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .onChange(of: designManager.isThinking) { _ in
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }

                Divider()

                HStack(spacing: 8) {
                    TextField("Describe a feature or issue...", text: $inputText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { sendMessage() }

                    Button("Send") { sendMessage() }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || designManager.isThinking)
                }
                .padding()
            }
            .frame(minWidth: 400)

            // Right: Parsed suggestions
            VStack(spacing: 0) {
                HStack {
                    Text("Issue Suggestions")
                        .font(.headline)
                    Spacer()
                }
                .padding()

                Divider()

                ScrollView {
                    let suggestions = parseSuggestions()
                    if suggestions.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary.opacity(0.4))
                            Text("Suggestions will appear here")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Describe what you want to build and Claude will suggest GitHub issues.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(suggestions) { suggestion in
                                SuggestionCard(
                                    suggestion: suggestion,
                                    isCreated: createdIssues.contains(suggestion.title),
                                    onCreate: { createIssue(suggestion) }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .frame(minWidth: 280, idealWidth: 320)
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        designManager.sendMessage(text)
        inputText = ""
    }

    private func parseSuggestions() -> [IssueSuggestion] {
        let assistantMessages = designManager.conversation.messages.filter { $0.role == "assistant" }
        guard let last = assistantMessages.last else { return [] }

        var suggestions: [IssueSuggestion] = []
        let content = last.content

        // Parse ## Issue: blocks
        let lines = content.components(separatedBy: "\n")
        var currentTitle: String?
        var currentLabels: [String] = []
        var currentMilestone: String?
        var currentBody: [String] = []

        for line in lines {
            if line.hasPrefix("## Issue:") || line.hasPrefix("## Issue :") {
                // Save previous if exists
                if let title = currentTitle {
                    suggestions.append(IssueSuggestion(
                        title: title,
                        body: currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
                        labels: currentLabels,
                        milestone: currentMilestone
                    ))
                }
                currentTitle = line.replacingOccurrences(of: "## Issue:", with: "")
                    .replacingOccurrences(of: "## Issue :", with: "")
                    .trimmingCharacters(in: .whitespaces)
                currentLabels = []
                currentMilestone = nil
                currentBody = []
            } else if line.hasPrefix("**Labels:**") || line.hasPrefix("**Labels: **") {
                let labelStr = line.replacingOccurrences(of: "**Labels:**", with: "")
                    .replacingOccurrences(of: "**Labels: **", with: "")
                    .trimmingCharacters(in: .whitespaces)
                currentLabels = labelStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            } else if line.hasPrefix("**Milestone:**") || line.hasPrefix("**Milestone: **") {
                currentMilestone = line.replacingOccurrences(of: "**Milestone:**", with: "")
                    .replacingOccurrences(of: "**Milestone: **", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if currentTitle != nil {
                currentBody.append(line)
            }
        }

        // Save last one
        if let title = currentTitle {
            suggestions.append(IssueSuggestion(
                title: title,
                body: currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
                labels: currentLabels,
                milestone: currentMilestone
            ))
        }

        // Fallback: if no structured format found, show raw content as a single suggestion
        if suggestions.isEmpty && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let firstLine = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? "New Issue"
            suggestions.append(IssueSuggestion(
                title: firstLine.prefix(80).trimmingCharacters(in: .whitespaces),
                body: content,
                labels: [],
                milestone: nil
            ))
        }

        return suggestions
    }

    private func createIssue(_ suggestion: IssueSuggestion) {
        designManager.createIssue(
            title: suggestion.title,
            body: suggestion.body,
            labels: suggestion.labels,
            milestone: suggestion.milestone,
            project: designManager.project
        ) { success in
            if success {
                createdIssues.insert(suggestion.title)
                github.refresh()
            }
        }
    }
}

struct IssueSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let labels: [String]
    let milestone: String?
}

private struct ChatBubble: View {
    let message: DesignMessage

    var body: some View {
        HStack {
            if message.role == "user" { Spacer(minLength: 60) }

            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(.body))
                    .textSelection(.enabled)
                    .padding(10)
                    .background(message.role == "user" ? Color.purple.opacity(0.15) : Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)

                Text(timeAgo(message.timestamp))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            if message.role == "assistant" { Spacer(minLength: 60) }
        }
    }
}

private struct SuggestionCard: View {
    let suggestion: IssueSuggestion
    let isCreated: Bool
    let onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(suggestion.title)
                .font(.system(.body, design: .default))
                .fontWeight(.semibold)
                .lineLimit(3)

            if !suggestion.labels.isEmpty {
                HStack(spacing: 4) {
                    ForEach(suggestion.labels, id: \.self) { label in
                        Text(label)
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.12))
                            .cornerRadius(4)
                    }
                }
            }

            if let ms = suggestion.milestone, !ms.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(ms)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text(String(suggestion.body.prefix(200)))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(4)

            HStack {
                Spacer()
                if isCreated {
                    Label("Created", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Button(action: onCreate) {
                        Label("Create Issue", systemImage: "plus.circle.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.small)
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}

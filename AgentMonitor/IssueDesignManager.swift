import Foundation

class IssueDesignManager: ObservableObject {
    @Published var conversation: DesignConversation = DesignConversation()
    @Published var isThinking = false

    let project: Project
    private var currentProcess: Process?

    init(project: Project) {
        self.project = project
    }

    func startNewConversation() {
        currentProcess?.terminate()
        currentProcess = nil
        conversation = DesignConversation()
        isThinking = false
    }

    func sendMessage(_ text: String) {
        let userMsg = DesignMessage(role: "user", content: text)
        conversation.messages.append(userMsg)
        isThinking = true

        let hasSession = conversation.claudeSessionId != nil

        let process = Process()
        configureProcess(process)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")

        let systemPrompt = """
        You are helping design GitHub issues for a software project. \
        When proposing an issue, use this format:

        ## Issue: <title>
        **Labels:** label1, label2
        **Milestone:** milestone name

        <issue body in markdown>

        You may propose multiple issues. Be specific and actionable.
        """

        var args = ["claude"]
        if let sid = conversation.claudeSessionId, hasSession {
            args += ["--resume", sid, "-p", text]
        } else {
            args += ["-p", "\(systemPrompt)\n\nUser request: \(text)"]
        }
        args += ["--output-format", "stream-json", "--dangerously-skip-permissions"]

        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: project.path)

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        currentProcess = process

        var accumulated = ""

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fileHandle = outPipe.fileHandleForReading
            var buffer = Data()

            while true {
                let chunk = fileHandle.availableData
                if chunk.isEmpty { break }
                buffer.append(chunk)

                while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                    let lineData = buffer[buffer.startIndex..<newlineIndex]
                    buffer = Data(buffer[buffer.index(after: newlineIndex)...])

                    guard let lineStr = String(data: lineData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                          !lineStr.isEmpty,
                          let data = lineStr.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        continue
                    }

                    let type = json["type"] as? String ?? ""

                    switch type {
                    case "assistant":
                        if let message = json["message"] as? [String: Any],
                           let content = message["content"] as? [[String: Any]] {
                            for block in content {
                                if block["type"] as? String == "text",
                                   let text = block["text"] as? String {
                                    accumulated += text
                                    let current = accumulated
                                    DispatchQueue.main.async {
                                        self?.updateAssistantMessage(current)
                                    }
                                }
                            }
                        }
                        if let sid = json["session_id"] as? String {
                            DispatchQueue.main.async {
                                self?.conversation.claudeSessionId = sid
                            }
                        }

                    case "content_block_delta":
                        if let delta = json["delta"] as? [String: Any],
                           delta["type"] as? String == "text_delta",
                           let text = delta["text"] as? String {
                            accumulated += text
                            let current = accumulated
                            DispatchQueue.main.async {
                                self?.updateAssistantMessage(current)
                            }
                        }

                    case "result":
                        if let sid = json["session_id"] as? String {
                            DispatchQueue.main.async {
                                self?.conversation.claudeSessionId = sid
                            }
                        }

                    default:
                        break
                    }
                }
            }
        }

        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isThinking = false
                self?.currentProcess = nil
            }
        }

        do {
            try process.run()
        } catch {
            isThinking = false
            let errMsg = DesignMessage(role: "assistant", content: "Failed to launch claude: \(error.localizedDescription)")
            conversation.messages.append(errMsg)
        }
    }

    private func updateAssistantMessage(_ text: String) {
        // Update the last assistant message or add a new one
        if let lastIdx = conversation.messages.indices.last,
           conversation.messages[lastIdx].role == "assistant" {
            conversation.messages[lastIdx] = DesignMessage(
                id: conversation.messages[lastIdx].id,
                role: "assistant",
                content: text,
                timestamp: conversation.messages[lastIdx].timestamp
            )
        } else {
            conversation.messages.append(DesignMessage(role: "assistant", content: text))
        }
    }

    func createIssue(title: String, body: String, labels: [String], milestone: String?, project: Project, completion: @escaping (Bool) -> Void) {
        var args = ["gh", "issue", "create", "--title", title, "--body", body]

        if !labels.isEmpty {
            args += ["--label", labels.joined(separator: ",")]
        }
        if let ms = milestone, !ms.isEmpty {
            args += ["--milestone", ms]
        }

        let process = Process()
        configureProcess(process)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: project.path)

        let errPipe = Pipe()
        process.standardOutput = Pipe()
        process.standardError = errPipe

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
                process.waitUntilExit()
                let success = process.terminationStatus == 0
                DispatchQueue.main.async { completion(success) }
            } catch {
                DispatchQueue.main.async { completion(false) }
            }
        }
    }

    deinit {
        currentProcess?.terminate()
    }
}

import Foundation
import AppKit

class AgentMonitor: ObservableObject {
    @Published var sessions: [AgentSession] = []
    @Published var isLoading = false
    @Published var lastUpdate: Date = Date()

    let project: Project
    private var processes: [String: Process] = [:]
    private var durationTimer: Timer?

    init(project: Project) {
        self.project = project
        // Timer to update durations for running sessions
        DispatchQueue.main.async { [weak self] in
            self?.startDurationTimer()
        }
    }

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let hasRunning = self.sessions.contains { $0.status == .running }
            if hasRunning {
                self.objectWillChange.send()
            }
        }
    }

    // MARK: - Launch Agent

    func launchAgent(prompt: String) {
        let session = AgentSession(prompt: prompt)
        sessions.insert(session, at: 0)
        isLoading = true

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "claude",
            "-p", prompt,
            "--output-format", "stream-json",
            "--verbose",
            "--dangerously-skip-permissions"
        ]
        process.currentDirectoryURL = URL(fileURLWithPath: project.path)

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let sessionId = session.id
        processes[sessionId] = process

        // Read stdout on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.readOutput(pipe: outPipe, sessionId: sessionId)
        }

        // Read stderr for errors
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.readStderr(pipe: errPipe, sessionId: sessionId)
        }

        // Handle process termination
        process.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let idx = self.sessions.firstIndex(where: { $0.id == sessionId }) {
                    if self.sessions[idx].status == .running {
                        self.sessions[idx].status = proc.terminationStatus == 0 ? .completed : .failed
                    }
                    self.sessions[idx].lastActivity = Date()
                }
                self.processes.removeValue(forKey: sessionId)
                self.isLoading = self.processes.values.contains { $0.isRunning }
                self.lastUpdate = Date()

                NSSound(named: "Glass")?.play()
            }
        }

        do {
            try process.run()
        } catch {
            if let idx = sessions.firstIndex(where: { $0.id == sessionId }) {
                sessions[idx].status = .failed
                sessions[idx].outputLines.append(AgentSession.OutputLine(
                    timestamp: Date(),
                    type: "error",
                    content: "Failed to launch claude: \(error.localizedDescription). Make sure 'claude' CLI is in your PATH."
                ))
            }
            processes.removeValue(forKey: sessionId)
            isLoading = false
        }
    }

    // MARK: - Send Follow-Up

    func sendFollowUp(sessionId: String, prompt: String) {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionId }),
              let claudeSessionId = sessions[idx].sessionId else { return }

        sessions[idx].status = .running
        sessions[idx].outputLines.append(AgentSession.OutputLine(
            timestamp: Date(),
            type: "system",
            content: "Follow-up: \(prompt)"
        ))

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "claude",
            "--resume", claudeSessionId,
            "-p", prompt,
            "--output-format", "stream-json",
            "--verbose",
            "--dangerously-skip-permissions"
        ]
        process.currentDirectoryURL = URL(fileURLWithPath: project.path)

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let internalId = sessions[idx].id
        processes[internalId] = process

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.readOutput(pipe: outPipe, sessionId: internalId)
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.readStderr(pipe: errPipe, sessionId: internalId)
        }

        process.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let idx = self.sessions.firstIndex(where: { $0.id == internalId }) {
                    if self.sessions[idx].status == .running {
                        self.sessions[idx].status = proc.terminationStatus == 0 ? .completed : .failed
                    }
                    self.sessions[idx].lastActivity = Date()
                }
                self.processes.removeValue(forKey: internalId)
                self.isLoading = self.processes.values.contains { $0.isRunning }
                NSSound(named: "Glass")?.play()
            }
        }

        do {
            try process.run()
            isLoading = true
        } catch {
            sessions[idx].status = .failed
            sessions[idx].outputLines.append(AgentSession.OutputLine(
                timestamp: Date(), type: "error", content: "Failed to resume: \(error.localizedDescription)"
            ))
        }
    }

    // MARK: - Stop Agent

    func stopAgent(sessionId: String) {
        if let process = processes[sessionId], process.isRunning {
            process.terminate()
        }
    }

    // MARK: - Output Reading

    private func readOutput(pipe: Pipe, sessionId: String) {
        let fileHandle = pipe.fileHandleForReading
        var buffer = Data()

        while true {
            let chunk = fileHandle.availableData
            if chunk.isEmpty { break }

            buffer.append(chunk)

            while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let lineData = buffer[buffer.startIndex..<newlineIndex]
                buffer = Data(buffer[buffer.index(after: newlineIndex)...])

                if let lineStr = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !lineStr.isEmpty {
                    processJSONLine(lineStr, sessionId: sessionId)
                }
            }
        }
    }

    private func readStderr(pipe: Pipe, sessionId: String) {
        let fileHandle = pipe.fileHandleForReading
        let data = fileHandle.readDataToEndOfFile()
        if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !str.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.appendOutput(sessionId: sessionId, type: "error", content: str)
            }
        }
    }

    // MARK: - JSONL Parsing

    private func processJSONLine(_ line: String, sessionId: String) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Non-JSON output, show as plain text
            DispatchQueue.main.async { [weak self] in
                self?.appendOutput(sessionId: sessionId, type: "assistant", content: line)
            }
            return
        }

        let type = json["type"] as? String ?? "unknown"

        switch type {
        case "assistant":
            // Extract text from message content blocks
            if let message = json["message"] as? [String: Any],
               let content = message["content"] as? [[String: Any]] {
                for block in content {
                    if block["type"] as? String == "text",
                       let text = block["text"] as? String,
                       !text.isEmpty {
                        DispatchQueue.main.async { [weak self] in
                            self?.appendOutput(sessionId: sessionId, type: "assistant", content: text)
                        }
                    }
                }
            }
            // Capture session_id
            if let sid = json["session_id"] as? String {
                DispatchQueue.main.async { [weak self] in
                    self?.updateSessionId(internalId: sessionId, claudeSessionId: sid)
                }
            }

        case "content_block_delta":
            if let delta = json["delta"] as? [String: Any],
               delta["type"] as? String == "text_delta",
               let text = delta["text"] as? String,
               !text.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    self?.appendOrUpdateAssistant(sessionId: sessionId, text: text)
                }
            }

        case "tool_use":
            let toolName = json["tool"] as? String ?? json["name"] as? String ?? "tool"
            var desc = toolName
            if let input = json["input"] as? [String: Any] {
                if let path = input["file_path"] as? String ?? input["path"] as? String {
                    desc += " \(path)"
                } else if let command = input["command"] as? String {
                    desc += " \(String(command.prefix(100)))"
                } else if let pattern = input["pattern"] as? String {
                    desc += " \(pattern)"
                } else if let query = input["query"] as? String {
                    desc += " \(String(query.prefix(80)))"
                }
            }
            DispatchQueue.main.async { [weak self] in
                self?.appendOutput(sessionId: sessionId, type: "tool_use", content: desc)
            }

        case "tool_result":
            // Skip verbose tool results
            break

        case "result":
            if let sid = json["session_id"] as? String {
                DispatchQueue.main.async { [weak self] in
                    self?.updateSessionId(internalId: sessionId, claudeSessionId: sid)
                }
            }
            if let cost = json["cost_usd"] as? Double ?? (json["cost_usd"] as? NSNumber)?.doubleValue {
                DispatchQueue.main.async { [weak self] in
                    if let self = self, let idx = self.sessions.firstIndex(where: { $0.id == sessionId }) {
                        self.sessions[idx].costUSD = cost
                    }
                }
            }
            let subtype = json["subtype"] as? String ?? ""
            if subtype == "error" {
                let errorMsg = json["error"] as? String ?? "Agent returned an error"
                DispatchQueue.main.async { [weak self] in
                    self?.appendOutput(sessionId: sessionId, type: "error", content: errorMsg)
                    if let self = self, let idx = self.sessions.firstIndex(where: { $0.id == sessionId }) {
                        self.sessions[idx].status = .failed
                    }
                }
            }

        case "system":
            if let sid = json["session_id"] as? String {
                DispatchQueue.main.async { [weak self] in
                    self?.updateSessionId(internalId: sessionId, claudeSessionId: sid)
                }
            }

        default:
            break
        }
    }

    // MARK: - State Updates

    private func appendOutput(sessionId: String, type: String, content: String) {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[idx].outputLines.append(AgentSession.OutputLine(
            timestamp: Date(), type: type, content: content
        ))
        sessions[idx].lastActivity = Date()
        lastUpdate = Date()
    }

    private func appendOrUpdateAssistant(sessionId: String, text: String) {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        // If the last line is an assistant message, append to it (streaming delta)
        if let lastIdx = sessions[idx].outputLines.indices.last,
           sessions[idx].outputLines[lastIdx].type == "assistant" {
            let existing = sessions[idx].outputLines[lastIdx]
            sessions[idx].outputLines[lastIdx] = AgentSession.OutputLine(
                timestamp: existing.timestamp, type: "assistant", content: existing.content + text
            )
        } else {
            sessions[idx].outputLines.append(AgentSession.OutputLine(
                timestamp: Date(), type: "assistant", content: text
            ))
        }
        sessions[idx].lastActivity = Date()
    }

    private func updateSessionId(internalId: String, claudeSessionId: String) {
        if let idx = sessions.firstIndex(where: { $0.id == internalId }) {
            sessions[idx].sessionId = claudeSessionId
        }
    }

    // MARK: - Compatibility

    func refresh() {
        lastUpdate = Date()
    }

    func getLogForSession(_ sessionId: String) async -> String {
        if let session = sessions.first(where: { $0.id == sessionId }) {
            return session.fullOutput
        }
        return "No output available"
    }

    deinit {
        durationTimer?.invalidate()
        for (_, process) in processes {
            if process.isRunning {
                process.terminate()
            }
        }
    }
}

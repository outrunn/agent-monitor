import Foundation
import AppKit

class AgentMonitor: ObservableObject {
    @Published var sessions: [AgentSession] = []
    @Published var isLoading = false
    @Published var lastUpdate: Date = Date()

    let project: Project
    var onSessionFinished: ((AgentSession) -> Void)?
    private var processes: [String: Process] = [:]
    private var durationTimer: Timer?
    private let sessionStore: SessionStore
    private var outputSaveTimer: Timer?
    private var dirtySessionIds: Set<String> = []

    init(project: Project) {
        self.project = project
        self.sessionStore = SessionStore(projectId: project.id)

        // Load persisted sessions
        var loaded = sessionStore.loadSessions()
        // Flip any running sessions to interrupted (they were running when app died)
        for i in loaded.indices {
            if loaded[i].status == .running {
                loaded[i].status = .interrupted
            }
        }
        self.sessions = loaded
        if !loaded.isEmpty {
            sessionStore.saveMetadata(loaded)
        }

        NotificationManager.shared.requestPermission()

        DispatchQueue.main.async { [weak self] in
            self?.startDurationTimer()
            self?.startOutputSaveTimer()
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

    private func startOutputSaveTimer() {
        outputSaveTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.flushDirtyOutputs()
        }
    }

    private func flushDirtyOutputs() {
        let ids = dirtySessionIds
        dirtySessionIds.removeAll()
        for id in ids {
            if let session = sessions.first(where: { $0.id == id }) {
                sessionStore.saveOutputLines(sessionId: id, lines: session.outputLines)
            }
        }
    }

    private func persistMetadata() {
        sessionStore.saveMetadata(sessions)
    }

    private func markOutputDirty(_ sessionId: String) {
        dirtySessionIds.insert(sessionId)
    }

    // MARK: - Launch Agent

    func launchAgent(prompt: String) {
        var session = AgentSession(prompt: prompt, projectId: project.id)
        session.projectId = project.id
        sessions.insert(session, at: 0)
        isLoading = true
        persistMetadata()

        let process = Process()
        configureProcess(process)
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

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.readOutput(pipe: outPipe, sessionId: sessionId)
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.readStderr(pipe: errPipe, sessionId: sessionId)
        }

        process.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let idx = self.sessions.firstIndex(where: { $0.id == sessionId }) {
                    if self.sessions[idx].status == .running {
                        self.sessions[idx].status = proc.terminationStatus == 0 ? .completed : .failed
                    }
                    self.sessions[idx].lastActivity = Date()
                    // Flush output immediately on completion
                    self.sessionStore.saveOutputLines(sessionId: sessionId, lines: self.sessions[idx].outputLines)
                    self.dirtySessionIds.remove(sessionId)
                    self.onSessionFinished?(self.sessions[idx])

                    NSSound(named: "Glass")?.play()
                    NotificationManager.shared.notify(session: self.sessions[idx])
                }
                self.processes.removeValue(forKey: sessionId)
                self.isLoading = self.processes.values.contains { $0.isRunning }
                self.lastUpdate = Date()
                self.persistMetadata()
                self.captureDiff(sessionId: sessionId)
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
            persistMetadata()
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
        persistMetadata()
        markOutputDirty(sessionId)

        let process = Process()
        configureProcess(process)
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
                    self.sessionStore.saveOutputLines(sessionId: internalId, lines: self.sessions[idx].outputLines)
                    self.dirtySessionIds.remove(internalId)
                    self.onSessionFinished?(self.sessions[idx])

                    NSSound(named: "Glass")?.play()
                    NotificationManager.shared.notify(session: self.sessions[idx])
                }
                self.processes.removeValue(forKey: internalId)
                self.isLoading = self.processes.values.contains { $0.isRunning }
                self.persistMetadata()
                self.captureDiff(sessionId: internalId)
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
            persistMetadata()
        }
    }

    // MARK: - Stop Agent

    func stopAgent(sessionId: String) {
        if let process = processes[sessionId], process.isRunning {
            process.terminate()
        }
    }

    // MARK: - Remove Session

    func removeSession(id: String) {
        sessions.removeAll { $0.id == id }
        persistMetadata()
    }

    // MARK: - Clear Completed Sessions

    func clearCompleted() {
        sessions.removeAll { $0.status == .completed || $0.status == .failed || $0.status == .interrupted }
        persistMetadata()
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
            DispatchQueue.main.async { [weak self] in
                self?.appendOutput(sessionId: sessionId, type: "assistant", content: line)
            }
            return
        }

        let type = json["type"] as? String ?? "unknown"

        switch type {
        case "assistant":
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
                        self.persistMetadata()
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
                        self.persistMetadata()
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
        markOutputDirty(sessionId)
    }

    private func appendOrUpdateAssistant(sessionId: String, text: String) {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        if let lastIdx = sessions[idx].outputLines.indices.last,
           sessions[idx].outputLines[lastIdx].type == "assistant" {
            let existing = sessions[idx].outputLines[lastIdx]
            sessions[idx].outputLines[lastIdx] = AgentSession.OutputLine(
                id: existing.id, timestamp: existing.timestamp, type: "assistant", content: existing.content + text
            )
        } else {
            sessions[idx].outputLines.append(AgentSession.OutputLine(
                timestamp: Date(), type: "assistant", content: text
            ))
        }
        sessions[idx].lastActivity = Date()
        markOutputDirty(sessionId)
    }

    private func updateSessionId(internalId: String, claudeSessionId: String) {
        if let idx = sessions.firstIndex(where: { $0.id == internalId }) {
            sessions[idx].sessionId = claudeSessionId
            persistMetadata()
        }
    }

    // MARK: - Git Diff Capture

    private func runGitCommand(_ args: [String], in dir: String) -> String? {
        let process = Process()
        configureProcess(process)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + args
        process.currentDirectoryURL = URL(fileURLWithPath: dir)
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    private func captureDiff(sessionId: String) {
        let dir = project.path
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            let unstaged = self.runGitCommand(["diff"], in: dir) ?? ""
            let staged = self.runGitCommand(["diff", "--cached"], in: dir) ?? ""

            var combined = ""
            if !unstaged.isEmpty || !staged.isEmpty {
                if !staged.isEmpty {
                    combined += "=== Staged Changes ===\n\(staged)\n"
                }
                if !unstaged.isEmpty {
                    combined += "=== Unstaged Changes ===\n\(unstaged)\n"
                }
            } else {
                // Agent may have committed — show last commit diff
                let lastCommit = self.runGitCommand(["log", "-1", "-p", "--format="], in: dir) ?? ""
                if !lastCommit.isEmpty {
                    combined = "=== Last Commit ===\n\(lastCommit)"
                }
            }

            guard !combined.isEmpty else { return }

            self.sessionStore.saveDiff(sessionId: sessionId, diff: combined)

            DispatchQueue.main.async {
                if let idx = self.sessions.firstIndex(where: { $0.id == sessionId }) {
                    self.sessions[idx].diffOutput = combined
                }
            }
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
        outputSaveTimer?.invalidate()

        // Sync flush all dirty outputs and mark running as interrupted
        for i in sessions.indices {
            if sessions[i].status == .running {
                sessions[i].status = .interrupted
            }
            sessionStore.saveOutputLinesSync(sessionId: sessions[i].id, lines: sessions[i].outputLines)
        }
        sessionStore.saveMetadataSync(sessions)

        for (_, process) in processes {
            if process.isRunning {
                process.terminate()
            }
        }
    }
}

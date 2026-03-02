import Foundation

class SessionStore {
    private let projectId: UUID
    private let sessionsDir: URL
    private let logsDir: URL
    private let metadataURL: URL
    private let writeQueue = DispatchQueue(label: "com.agentmonitor.sessionstore", qos: .utility)

    init(projectId: UUID) {
        self.projectId = projectId

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let baseDir = appSupport.appendingPathComponent("AgentMonitor/sessions/\(projectId.uuidString)")
        self.sessionsDir = baseDir
        self.logsDir = baseDir.appendingPathComponent("logs")
        self.metadataURL = baseDir.appendingPathComponent("sessions.json")

        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
    }

    // MARK: - Load

    func loadSessions() -> [AgentSession] {
        guard let data = try? Data(contentsOf: metadataURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard var sessions = try? decoder.decode([AgentSession].self, from: data) else { return [] }

        // Load output lines and diffs for each session
        for i in sessions.indices {
            let logURL = logsDir.appendingPathComponent("\(sessions[i].id).json")
            if let logData = try? Data(contentsOf: logURL),
               let lines = try? decoder.decode([AgentSession.OutputLine].self, from: logData) {
                sessions[i].outputLines = lines
            }
            sessions[i].diffOutput = loadDiff(sessionId: sessions[i].id)
        }

        return sessions
    }

    // MARK: - Save Metadata

    func saveMetadata(_ sessions: [AgentSession]) {
        writeQueue.async { [metadataURL] in
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted

            // Strip outputLines from metadata to keep it small
            var stripped = sessions
            for i in stripped.indices {
                stripped[i].outputLines = []
            }

            guard let data = try? encoder.encode(stripped) else { return }
            try? data.write(to: metadataURL, options: .atomic)
        }
    }

    // MARK: - Save Output Lines

    func saveOutputLines(sessionId: String, lines: [AgentSession.OutputLine]) {
        writeQueue.async { [logsDir] in
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(lines) else { return }
            let logURL = logsDir.appendingPathComponent("\(sessionId).json")
            try? data.write(to: logURL, options: .atomic)
        }
    }

    // MARK: - Diff

    func saveDiff(sessionId: String, diff: String) {
        writeQueue.async { [logsDir] in
            let diffURL = logsDir.appendingPathComponent("\(sessionId)-diff.txt")
            try? diff.write(to: diffURL, atomically: true, encoding: .utf8)
        }
    }

    func loadDiff(sessionId: String) -> String? {
        let diffURL = logsDir.appendingPathComponent("\(sessionId)-diff.txt")
        return try? String(contentsOf: diffURL, encoding: .utf8)
    }

    // MARK: - Sync Save (for deinit / flush)

    func saveMetadataSync(_ sessions: [AgentSession]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        var stripped = sessions
        for i in stripped.indices {
            stripped[i].outputLines = []
        }

        guard let data = try? encoder.encode(stripped) else { return }
        try? data.write(to: metadataURL, options: .atomic)
    }

    func saveOutputLinesSync(sessionId: String, lines: [AgentSession.OutputLine]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(lines) else { return }
        let logURL = logsDir.appendingPathComponent("\(sessionId).json")
        try? data.write(to: logURL, options: .atomic)
    }
}

import Foundation

class GitHubManager: ObservableObject {
    @Published var milestones: [GitHubMilestone] = []
    @Published var issues: [GitHubIssue] = []
    @Published var closedCount: Int = 0
    @Published var isLoading = false
    @Published var lastUpdate: Date = Date()
    @Published var errorMessage: String?

    let project: Project
    private var autoRefreshTimer: Timer?
    private var errorDismissTimer: Timer?

    init(project: Project) {
        self.project = project
        refresh()
        DispatchQueue.main.async { [weak self] in
            self?.startAutoRefresh()
        }
    }

    private func startAutoRefresh() {
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        isLoading = true
        errorMessage = nil

        Task {
            await fetchMilestones()
            await fetchIssues()
            await fetchClosedCount()

            DispatchQueue.main.async {
                self.lastUpdate = Date()
                self.isLoading = false
            }
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        errorDismissTimer?.invalidate()
        errorDismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.errorMessage = nil
        }
    }

    // MARK: - Fetch Issue Body

    func fetchIssueBody(number: Int, completion: @escaping (String?, String?) -> Void) {
        let process = Process()
        configureProcess(process)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "issue", "view", "\(number)",
                           "--json", "body,title,labels"]
        process.currentDirectoryURL = URL(fileURLWithPath: project.path)

        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if process.terminationStatus == 0,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let title = json["title"] as? String ?? ""
                    let body = json["body"] as? String ?? ""
                    DispatchQueue.main.async {
                        completion(title, body)
                    }
                } else {
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let errStr = String(data: errData, encoding: .utf8) ?? "Failed to fetch issue"
                    DispatchQueue.main.async {
                        self.showError(errStr)
                        completion(nil, nil)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.showError("Failed to run gh: \(error.localizedDescription)")
                    completion(nil, nil)
                }
            }
        }
    }

    // MARK: - Close Issue

    func closeIssue(number: Int, comment: String? = nil, completion: ((Bool) -> Void)? = nil) {
        var args = ["gh", "issue", "close", "\(number)"]
        if let comment = comment, !comment.isEmpty {
            args += ["--comment", comment]
        }

        let process = Process()
        configureProcess(process)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: project.path)

        let errPipe = Pipe()
        process.standardError = errPipe

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
                process.waitUntilExit()

                let success = process.terminationStatus == 0
                DispatchQueue.main.async {
                    if !success {
                        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                        self.showError(String(data: errData, encoding: .utf8) ?? "Failed to close issue")
                    }
                    completion?(success)
                    if success {
                        self.refresh()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.showError("Failed to run gh: \(error.localizedDescription)")
                    completion?(false)
                }
            }
        }
    }

    // MARK: - Labels

    static let inProgressLabel = "in progress"

    func addInProgressLabel(number: Int) {
        ensureLabelExists { [weak self] in
            self?.editLabel(number: number, add: true)
        }
    }

    func removeInProgressLabel(number: Int) {
        editLabel(number: number, add: false)
    }

    private func editLabel(number: Int, add: Bool) {
        let flag = add ? "--add-label" : "--remove-label"
        let process = Process()
        configureProcess(process)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "issue", "edit", "\(number)", flag, GitHubManager.inProgressLabel]
        process.currentDirectoryURL = URL(fileURLWithPath: project.path)
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        DispatchQueue.global(qos: .utility).async {
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 && !add {
                    // After removing label, refresh to update UI
                    DispatchQueue.main.async { [weak self] in
                        self?.refresh()
                    }
                }
            } catch {
                // Label operations are best-effort
            }
        }
    }

    private var labelEnsured = false

    private func ensureLabelExists(then: @escaping () -> Void) {
        if labelEnsured {
            then()
            return
        }
        let process = Process()
        configureProcess(process)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "label", "create", GitHubManager.inProgressLabel,
                           "--color", "FFA500", "--description", "An agent is working on this",
                           "--force"]
        process.currentDirectoryURL = URL(fileURLWithPath: project.path)
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        DispatchQueue.global(qos: .utility).async { [weak self] in
            do {
                try process.run()
                process.waitUntilExit()
                self?.labelEnsured = true
            } catch {
                // Best effort
            }
            DispatchQueue.main.async {
                then()
            }
        }
    }

    // MARK: - Add Comment

    func addIssueComment(number: Int, comment: String, completion: ((Bool) -> Void)? = nil) {
        let process = Process()
        configureProcess(process)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "issue", "comment", "\(number)", "--body", comment]
        process.currentDirectoryURL = URL(fileURLWithPath: project.path)

        let errPipe = Pipe()
        process.standardError = errPipe

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
                process.waitUntilExit()

                let success = process.terminationStatus == 0
                DispatchQueue.main.async {
                    if !success {
                        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                        self.showError(String(data: errData, encoding: .utf8) ?? "Failed to add comment")
                    }
                    completion?(success)
                }
            } catch {
                DispatchQueue.main.async {
                    self.showError("Failed to run gh: \(error.localizedDescription)")
                    completion?(false)
                }
            }
        }
    }

    // MARK: - Fetch Data

    private func fetchMilestones() async {
        let process = Process()
        configureProcess(process)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "api", "repos/:owner/:repo/milestones?per_page=100&state=open",
                           "--jq", "[.[] | {number, title, open_issues, closed_issues, due_on}]"]
        process.currentDirectoryURL = URL(fileURLWithPath: project.path)

        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let decoder = JSONDecoder()
            // Don't use .convertFromSnakeCase — CodingKeys already handle the mapping

            do {
                let milestones = try decoder.decode([GitHubMilestone].self, from: data)
                DispatchQueue.main.async {
                    // Sort by due date (soonest first), then by number
                    self.milestones = milestones.sorted { a, b in
                        if let aDate = a.parsedDueDate, let bDate = b.parsedDueDate {
                            return aDate < bDate
                        }
                        if a.dueOn != nil && b.dueOn == nil { return true }
                        if a.dueOn == nil && b.dueOn != nil { return false }
                        return a.number < b.number
                    }
                }
            } catch {
                print("Milestone decode error: \(error)")
                DispatchQueue.main.async {
                    self.showError("Failed to decode milestones: \(error.localizedDescription)")
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.showError("Error fetching milestones: \(error.localizedDescription)")
            }
        }
    }

    private func fetchIssues() async {
        let process = Process()
        configureProcess(process)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "issue", "list",
                           "--json", "number,title,state,milestone,labels",
                           "--limit", "500",
                           "--state", "open"]
        process.currentDirectoryURL = URL(fileURLWithPath: project.path)

        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            do {
                let issues = try JSONDecoder().decode([GitHubIssue].self, from: data)
                DispatchQueue.main.async {
                    self.issues = issues.filter { $0.state == "OPEN" }
                        .sorted { $0.number < $1.number }
                }
            } catch {
                // Log decode error and retry without labels
                print("Issue decode error: \(error)")
                DispatchQueue.main.async {
                    self.showError("Failed to decode issues: \(error.localizedDescription)")
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.showError("Error fetching issues: \(error.localizedDescription)")
            }
        }
    }

    private func fetchClosedCount() async {
        let process = Process()
        configureProcess(process)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "issue", "list",
                           "--state", "closed",
                           "--json", "number",
                           "--limit", "500",
                           "--jq", "length"]
        process.currentDirectoryURL = URL(fileURLWithPath: project.path)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let count = Int(str) {
                DispatchQueue.main.async {
                    self.closedCount = count
                }
            }
        } catch {
            // Non-critical
        }
    }

    func issuesForMilestone(_ milestoneNumber: Int) -> [GitHubIssue] {
        issues.filter { $0.milestone?.number == milestoneNumber }
            .sorted { $0.number < $1.number }
    }

    func issuesWithoutMilestone() -> [GitHubIssue] {
        issues.filter { $0.milestone == nil }
    }

    func openIssuesForMilestone(_ milestoneNumber: Int) -> [GitHubIssue] {
        issues.filter { $0.milestone?.number == milestoneNumber && $0.state == "OPEN" }
            .sorted { $0.number < $1.number }
    }

    deinit {
        autoRefreshTimer?.invalidate()
        errorDismissTimer?.invalidate()
    }
}

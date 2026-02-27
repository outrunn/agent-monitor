import Foundation

class GitHubManager: ObservableObject {
    @Published var milestones: [GitHubMilestone] = []
    @Published var issues: [GitHubIssue] = []
    @Published var isLoading = false
    @Published var lastUpdate: Date = Date()

    let project: Project

    init(project: Project) {
        self.project = project
    }

    func refresh() {
        isLoading = true

        Task {
            await fetchMilestones()
            await fetchIssues()

            DispatchQueue.main.async {
                self.lastUpdate = Date()
                self.isLoading = false
            }
        }
    }

    private func fetchMilestones() async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "api", "repos/:owner/:repo/milestones",
                           "--jq", "[.[] | {number, title, open_issues, closed_issues, due_on}]"]
        process.currentDirectoryURL = URL(fileURLWithPath: project.path)

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            if let milestones = try? decoder.decode([GitHubMilestone].self, from: data) {
                DispatchQueue.main.async {
                    self.milestones = milestones.sorted { $0.number < $1.number }
                }
            }
        } catch {
            print("Error fetching milestones: \(error)")
        }
    }

    private func fetchIssues() async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "issue", "list",
                           "--json", "number,title,state,milestone",
                           "--limit", "200"]
        process.currentDirectoryURL = URL(fileURLWithPath: project.path)

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let issues = try? JSONDecoder().decode([GitHubIssue].self, from: data) {
                DispatchQueue.main.async {
                    self.issues = issues.filter { $0.state == "OPEN" }
                        .sorted { $0.number > $1.number }
                }
            }
        } catch {
            print("Error fetching issues: \(error)")
        }
    }

    func issuesForMilestone(_ milestoneNumber: Int) -> [GitHubIssue] {
        issues.filter { $0.milestone?.number == milestoneNumber }
    }

    func issuesWithoutMilestone() -> [GitHubIssue] {
        issues.filter { $0.milestone == nil }
    }
}

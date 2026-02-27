import Foundation
import AppKit

class ProjectStore: ObservableObject {
    @Published var projects: [Project] = []
    @Published var selectedProject: Project?

    private let storageURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("AgentMonitor")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("projects.json")
        load()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([Project].self, from: data) else { return }
        // Only keep projects whose directories still exist
        projects = decoded.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    // MARK: - Actions

    func select(_ project: Project) {
        selectedProject = project
    }

    func goBack() {
        selectedProject = nil
    }

    func remove(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        if selectedProject?.id == project.id {
            selectedProject = nil
        }
        save()
    }

    func addExisting() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a project directory (must contain .git)"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let gitDir = url.appendingPathComponent(".git")
        guard FileManager.default.fileExists(atPath: gitDir.path) else {
            let alert = NSAlert()
            alert.messageText = "Not a Git Repository"
            alert.informativeText = "The selected directory doesn't contain a .git folder. Please choose a git-initialized project."
            alert.alertStyle = .warning
            alert.runModal()
            return
        }

        let project = Project(name: url.lastPathComponent, path: url.path)
        addAndSelect(project)
    }

    func createNew() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose parent directory for new project"
        panel.prompt = "Choose"

        guard panel.runModal() == .OK, let parentURL = panel.url else { return }

        let alert = NSAlert()
        alert.messageText = "New Project Name"
        alert.informativeText = "Enter a name for the new project:"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.placeholderString = "my-project"
        alert.accessoryView = input

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let name = input.stringValue.isEmpty ? "my-project" : input.stringValue
        let projectURL = parentURL.appendingPathComponent(name)

        do {
            try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["init"]
            process.currentDirectoryURL = projectURL
            try process.run()
            process.waitUntilExit()

            let project = Project(name: name, path: projectURL.path)
            addAndSelect(project)
        } catch {
            print("Error creating project: \(error)")
        }
    }

    private func addAndSelect(_ project: Project) {
        // Remove duplicate path if already exists
        projects.removeAll { $0.path == project.path }
        projects.insert(project, at: 0)
        save()
        selectedProject = project
    }
}

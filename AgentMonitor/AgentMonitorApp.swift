import SwiftUI

@main
struct AgentMonitorApp: App {
    @StateObject private var projectStore = ProjectStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if let project = projectStore.selectedProject {
                    ProjectView(project: project, onBack: { projectStore.goBack() })
                        .id(project.id)
                        .frame(width: 1100, height: 750)
                } else {
                    ProjectLauncherView(store: projectStore)
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

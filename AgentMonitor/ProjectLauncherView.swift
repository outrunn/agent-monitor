import SwiftUI

struct ProjectLauncherView: View {
    @ObservedObject var store: ProjectStore

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 48))
                    .foregroundColor(.purple)

                Text("Agent Monitor")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Select a project to monitor")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            .padding(.bottom, 24)

            Divider()

            // Project list
            if store.projects.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No projects yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Open an existing project or create a new one")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(store.projects) { project in
                            ProjectRow(project: project,
                                       onSelect: { store.select(project) },
                                       onRemove: { store.remove(project) })
                        }
                    }
                    .padding()
                }
            }

            Divider()

            // Actions
            HStack(spacing: 12) {
                Spacer()

                Button(action: { store.addExisting() }) {
                    Label("Open Existing", systemImage: "folder")
                }

                Button(action: { store.createNew() }) {
                    Label("Create New", systemImage: "plus.circle")
                }

                Spacer()
            }
            .padding()
        }
        .frame(width: 500, height: 550)
    }
}

struct ProjectRow: View {
    let project: Project
    let onSelect: () -> Void
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.title2)
                    .foregroundColor(.purple)

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.body)
                        .fontWeight(.medium)

                    Text(project.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                if isHovering {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(isHovering ? Color.purple.opacity(0.05) : Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

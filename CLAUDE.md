# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
./build.sh              # Build Release via xcodebuild
./run.sh                # Build (if needed) and launch the app
./open-in-xcode.sh      # Open project in Xcode (build with Cmd+R)
```

Direct build command:
```bash
xcodebuild -project AgentMonitor.xcodeproj -scheme AgentMonitor -configuration Release -derivedDataPath ./build clean build
```

The built app lands at `build/Build/Products/Release/AgentMonitor.app`.

There are no automated tests or linting configured.

## What This Is

A native macOS SwiftUI app (macOS 13+, Swift 5.9) that launches, monitors, and interacts with Claude Code agent sessions. Also shows GitHub project data. Supports multiple projects. Zero external dependencies — pure Foundation + SwiftUI + AppKit.

## Architecture

Source files in `AgentMonitor/` (flat structure):

### Core
- **AgentMonitorApp.swift** — `@main` entry point. Owns `ProjectStore` as app-wide `@StateObject`. Routes between launcher and project view based on `projectStore.selectedProject`.
- **Models.swift** — All data structs: `Project`, `AgentSession` (with `Status` enum, `OutputLine` struct), `GitHubMilestone`, `GitHubIssue`.
- **Helpers.swift** — Shared utilities: `timeAgo()` function, `StatusIndicator` view.

### State Management
- **ProjectStore.swift** — `ObservableObject` for project persistence. Saves/loads projects to `~/Library/Application Support/AgentMonitor/projects.json`. Handles NSOpenPanel for open/create, `git init` for new projects.
- **AgentMonitor.swift** — `ObservableObject` that manages Claude Code agent processes. Launches agents via `claude -p "prompt" --output-format stream-json --dangerously-skip-permissions`. Parses streaming JSONL output. Supports follow-up prompts via `--resume <session-id>`. Plays `NSSound("Glass")` on completion.
- **GitHubManager.swift** — `ObservableObject` that fetches milestones and issues via `gh` CLI. Accepts `Project` in init, uses project path as working directory.

### Views
- **ProjectLauncherView.swift** — Launch screen with recent projects list, open/create buttons, hover-to-reveal remove button.
- **ProjectView.swift** — Tab container after project selection. Header with back button, project name, segmented picker (Agents / Issues & Milestones). Owns `AgentMonitor` and `GitHubManager` as `@StateObject`.
- **AgentsTabView.swift** — "New Agent" button with prompt input, agent card list.
- **IssuesTabView.swift** — HSplitView: milestones/issues left, compact agents right.
- **AgentCardViews.swift** — `AgentCard` (full, with stop button) and `CompactAgentCard` (sidebar).
- **MilestoneViews.swift** — `MilestoneCard`, `IssueRow`, `UnassignedIssuesCard`, `EmptyGitHubView`.
- **LogView.swift** — Streaming agent output viewer with follow-up prompt input. Shows assistant text, tool usage, errors, and system messages.

## Key Patterns

- **Two-level navigation**: `ProjectStore.selectedProject` is nil -> launcher, non-nil -> project view. No NavigationStack needed.
- **Per-project state**: `AgentMonitor` and `GitHubManager` are `@StateObject` inside `ProjectView`, destroyed/recreated on project switch via `.id(project.id)`.
- **MVVM** via `@StateObject` / `@Published` — state changes automatically trigger SwiftUI re-renders.
- **Claude Code integration**: Agents launched as `Foundation.Process` running `claude` CLI. JSONL stream parsed line-by-line on background thread. Session ID captured from stream for follow-up/resume capability.
- Shell execution through `Foundation.Process` with `/usr/bin/env` for `claude` and `gh` commands.
- Duration timer updates running agent durations every second.
- Issue-to-agent mapping via regex extraction of `#<number>` from agent prompts.
- **Completion sound**: Plays Glass sound when any agent process terminates.
- **No sandbox**: Entitlements have `app-sandbox = false` since the app shells out to CLI tools.

## Runtime Dependencies

- **Claude Code CLI** (`claude`) — must be in PATH. Used for launching and resuming agent sessions.
- **GitHub CLI** (`gh`) — must be authenticated (`gh auth login`), runs from the selected project's directory

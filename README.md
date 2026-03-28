# Agent Monitor

A native macOS app for managing and orchestrating AI coding agents. Launch Claude Code sessions, track progress against GitHub issues, monitor costs, and view real-time logs — all from one interface.

![macOS](https://img.shields.io/badge/macOS-13.0+-black?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9+-F05138?style=flat-square&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-blue?style=flat-square)
![Zero Dependencies](https://img.shields.io/badge/dependencies-0-brightgreen?style=flat-square)

<!-- Add screenshot here: ![Agent Monitor](screenshot.png) -->

## What It Does

**Agent Monitor** turns multi-agent AI development from chaos into a dashboard. Instead of juggling terminal windows, you get:

- **Launch & track agents** from a unified interface with real-time status (running/completed/failed)
- **GitHub integration** — milestones, issues, and progress bars sync automatically; agents auto-link to the issues they're working on
- **Live log streaming** — click any agent to see its full output as it works
- **Cost tracking** — per-session and per-milestone API cost breakdowns
- **Multi-project support** — switch between projects instantly

## Architecture

```
AgentMonitor
├── Core (Models, AgentMonitor, SessionStore, ProjectStore)
├── Managers (GitHubManager, IssueDesignManager, NotificationManager)
└── Views (SwiftUI — ProjectView, AgentsTab, IssuesTab, LogView, CostDashboard)
```

**Pure Foundation + SwiftUI. Zero external dependencies.** All integrations (Claude Code CLI, GitHub CLI) via subprocess execution — lightweight, extensible, ~4.6MB compiled.

## Key Technical Decisions

**Real-time JSONL stream parsing** — Agent output is parsed line-by-line on a background thread, differentiating between assistant messages, tool calls, and system events. UI updates reactively via Combine.

**Dual-timer architecture** — Agent status refreshes every 3 seconds (fast feedback), GitHub data every 120 seconds (API-friendly). Both non-blocking.

**Smart agent-to-issue mapping** — Regex extracts issue numbers from agent prompts and automatically links running agents to their GitHub issues with visual badges.

**Session persistence** — Metadata and logs split into separate stores. Sessions survive app restarts. Atomic writes prevent corruption.

## Tech Stack

| | |
|-|-|
| **Language** | Swift 5.9+ with async/await |
| **UI** | SwiftUI (native macOS) |
| **State** | Combine + @Published reactive bindings |
| **Persistence** | Codable + FileManager (JSON) |
| **Integrations** | Claude Code CLI, GitHub CLI (subprocess) |
| **Size** | ~4,600 lines of Swift | 0 external dependencies |

## Getting Started

```bash
git clone https://github.com/outrunn/agent-monitor.git
cd agent-monitor
./run.sh
```

Requires: macOS 13+, Xcode 14+, Claude Code CLI, GitHub CLI (`gh`)

## License

MIT

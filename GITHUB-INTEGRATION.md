# GitHub Integration

Agent Monitor now includes comprehensive GitHub integration to show the full picture of your project!

## Features

### 🎯 Milestones View
- Shows all project milestones from the repository
- Progress bars showing completion percentage
- Open vs closed issue counts
- Visual indicators (green = almost done, orange = in progress, blue = just started)

### 📋 Issue Organization
- Issues grouped by milestone
- Unassigned issues shown separately
- Issue numbers and titles displayed clearly
- Click-to-expand milestone sections

### 🔗 Agent-to-Issue Mapping
- Visual badges showing which agents are working on which issues
- Real-time status indicators (green = running, red = failed, blue = completed)
- Click on agent badge to see full log
- Automatic issue number extraction from agent tasks

### 📊 Two-Panel Dashboard
**Left Panel:** Milestones & Issues
- Hierarchical view: Milestones → Issues → Assigned Agents
- Collapsible sections for clean organization
- Progress tracking at a glance

**Right Panel:** Active Agents
- Compact list of all running agents
- Quick status overview
- One-click log viewing

## How It Works

### Data Sources
1. **Milestones:** Fetched via `gh api repos/:owner/:repo/milestones`
2. **Issues:** Fetched via `gh issue list --json number,title,state,milestone`
3. **Agents:** Parsed from `openclaw process list`

### Auto-Refresh
- Both GitHub data and agent status refresh together
- Refresh button updates everything at once
- Auto-refresh every 3 seconds for agents (GitHub data persists)

### Issue Mapping
The app automatically matches agents to issues by:
- Extracting issue number from agent task (e.g., "Fix GitHub issue #80")
- Displaying agent badges next to the corresponding issue
- Color-coding by agent status

## UI Layout

```
╔═══════════════════════════════════════════════════════════════╗
║  🧠 Agent Monitor          [Dashboard|Agents]   🟢 just now ⟳ ║
╠══════════════════════════════╦════════════════════════════════╣
║ MILESTONES & ISSUES          ║ ACTIVE AGENTS                  ║
║                              ║                                ║
║ 🎯 SOFT LAUNCH (Week 1-2)    ║ 🟢 briny-zephyr    #80   9m    ║
║ [██████████░░░] 60%          ║    Fix depth limit             ║
║                              ║                                ║
║  #80 Cannot mine past depth  ║ 🟢 neat-seaslug    #83   9m    ║
║      🟢 briny-zephyr         ║    Cache persist               ║
║                              ║                                ║
║  #83 Cache not persisting    ║ 🟢 keen-cove       #88   9m    ║
║      🟢 neat-seaslug         ║    Admin auth                  ║
║                              ║                                ║
║  #88 Admin panel missing     ║ 🔴 delta-cloud     #80   23s   ║
║      🟢 keen-cove            ║    Fix depth limit (failed)    ║
║                              ║                                ║
║ 🚀 ALGORITHM READY (Week 3-4)║                                ║
║ [███░░░░░░░░] 20%            ║                                ║
║  ...                         ║                                ║
╚══════════════════════════════╩════════════════════════════════╝
```

## View Modes

### Dashboard Mode (Default)
- Two-panel layout
- Milestones + Issues on left
- Active agents on right
- Shows complete project hierarchy

### Agents Mode
- Full-screen agent list
- Same detailed agent cards as before
- Useful for focusing on agent status only

Toggle between views using the segmented control in the header.

## Visual Indicators

### Milestone Progress
- **Green** (70%+) - Almost complete!
- **Orange** (40-70%) - Making progress
- **Blue** (<40%) - Just getting started

### Agent Status
- **Green circle** - Agent currently working
- **Red circle** - Agent failed, needs attention
- **Blue circle** - Agent completed task

### Issue Highlighting
- Issues with assigned agents have a subtle green background
- Agent badges are color-coded by status
- Click any agent badge to view its log

## Requirements

### GitHub CLI (`gh`)
The app uses GitHub CLI to fetch repository data. Make sure:
1. `gh` is installed (`brew install gh`)
2. You're authenticated (`gh auth login`)
3. The repository path is correct

### Repository Path
Currently hardcoded to:
```
~/Dev/games/roblox/mine-for-brainrots
```

To change, edit `GitHubManager.swift` and update the `repoPath` variable.

## Benefits

### For James
**Before:** "What milestone are we working on? Which issues are being tackled?"

**After:** Complete visibility:
- See all milestones and progress
- Know which issues are being worked on
- Identify blocked or failed agents instantly
- Understand the full project status at a glance

### For Team Coordination
- Avoid duplicate work (see which issues have agents)
- Prioritize failed agents (red badges stand out)
- Track milestone progress in real-time
- Identify unassigned critical issues

## Pro Tips

1. **Collapse completed milestones** to focus on active work
2. **Click agent badges** from the issue list for quick log access
3. **Use "Agents" view** when you just want to monitor execution
4. **Watch progress bars** to celebrate milestone completion
5. **Check unassigned issues** to see what needs an agent

---

**Result:** Full transparency into your project's status, from high-level milestones down to individual agent actions.

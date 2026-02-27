# Agent Monitor v2

A beautiful native macOS app for monitoring Claude Code agents working on your Roblox game project - now with **GitHub integration**!

## ✨ What's New in v2

### GitHub Integration
- 🎯 **Milestone tracking** with visual progress bars
- 📋 **Issue organization** grouped by milestone
- 🔗 **Agent-to-issue mapping** showing who's working on what
- 📊 **Two-panel dashboard** for complete project visibility

See [GITHUB-INTEGRATION.md](GITHUB-INTEGRATION.md) for details.

## 🚀 Features

### Real-Time Agent Monitoring
- **Auto-refreshes** every 3 seconds
- **Color-coded status** (Green = running, Red = failed, Blue = completed)
- **Agent details:** ID, GitHub issue, task, duration
- **Live logs:** Click any agent to view full output

### GitHub Project Dashboard
- **Milestones** with progress indicators
- **Open issues** organized by milestone
- **Visual connections** between agents and issues
- **Unassigned issues** highlighted separately

### Dual View Modes
- **Dashboard Mode:** Milestones → Issues → Agents hierarchy
- **Agents Mode:** Traditional agent list view
- Toggle between modes with segmented control

### Native macOS Experience
- Beautiful SwiftUI interface
- Dark mode support
- Smooth animations
- Zero configuration needed

## 🏗️ Building

### Quick Start
```bash
cd ~/Dev/tools/agent-monitor
./open-in-xcode.sh
# Click Play (▶️) in Xcode
```

### Command Line Build
```bash
./build.sh
open build/Build/Products/Release/AgentMonitor.app
```

## 📊 What You'll See

### Dashboard View
**Left Panel:**
- Milestones with progress bars
- Issues grouped by milestone
- Agent badges showing assignments

**Right Panel:**
- Active agents list
- Quick status overview
- One-click log access

### Agents View
- Detailed agent cards
- Status, task, duration
- GitHub issue numbers
- Full log viewer

## 🛠️ Requirements

- **macOS 13.0+** (Ventura or later)
- **Xcode** (for building)
- **OpenClaw** installed and in PATH
- **GitHub CLI** (`gh`) for GitHub integration
  ```bash
  brew install gh
  gh auth login
  ```

## 📚 Documentation

- **[START-HERE.md](START-HERE.md)** - Quick 3-step start guide
- **[QUICKSTART.md](QUICKSTART.md)** - Detailed instructions
- **[GITHUB-INTEGRATION.md](GITHUB-INTEGRATION.md)** - GitHub features explained
- **[FEATURES-V2.md](FEATURES-V2.md)** - Complete feature list
- **[SUMMARY.md](SUMMARY.md)** - Technical architecture
- **[APP-PREVIEW.md](APP-PREVIEW.md)** - UI walkthrough

## 🎯 Use Cases

### "How's my project progressing?"
→ See milestone progress bars and issue counts

### "Which agents are working on which issues?"
→ Visual badges show agent assignments

### "Why did that agent fail?"
→ Click the red badge to see full logs

### "What issues need attention?"
→ Check unassigned issues section

## 💡 Visual Indicators

### Milestone Progress
- 🟢 **Green** (70%+) - Almost done!
- 🟠 **Orange** (40-70%) - In progress
- 🔵 **Blue** (<40%) - Just started

### Agent Status
- 🟢 **Green circle** - Currently working
- 🔴 **Red circle** - Failed, needs attention
- 🔵 **Blue circle** - Completed

### Issue Highlighting
- Light green background = Agent assigned
- Color-coded badges = Agent status
- Purple tags = Issue numbers

## 🚀 Quick Launch

```bash
cd ~/Dev/tools/agent-monitor
./RUN-ME-FIRST.sh  # Interactive menu
```

Or:

```bash
./open-in-xcode.sh  # Direct to Xcode
```

## 🔧 Configuration

Currently monitors:
- **Repository:** `~/Dev/games/roblox/mine-for-brainrots`
- **Processes:** All OpenClaw sessions
- **Refresh:** Every 3 seconds

To change the repository path, edit `GitHubManager.swift`.

## 🎉 Benefits

**Before v2:**
- ✅ See what agents are doing
- ❌ No project context
- ❌ No milestone tracking
- ❌ Manual issue checking

**After v2:**
- ✅ See what agents are doing
- ✅ Full project overview
- ✅ Milestone progress tracking
- ✅ Agent-to-issue mapping
- ✅ Complete visibility

---

Built with ❤️ for stress-free autonomous coding.

**v2.0** - Now with GitHub integration for complete project visibility!

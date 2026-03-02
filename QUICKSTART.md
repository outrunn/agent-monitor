# Quick Start Guide

## Option 1: Open in Xcode (Recommended)

The easiest way to run Agent Monitor:

1. **Open the project:**
   ```bash
   open ~/Dev/tools/agent-monitor/AgentMonitor.xcodeproj
   ```

2. **Click the Play button** (or press ⌘R)

That's it! The app will launch and immediately start monitoring your agents.

## Option 2: Build from Terminal

If you prefer the command line:

```bash
cd ~/Dev/tools/agent-monitor
./build.sh
```

Then open the built app:

```bash
open build/Build/Products/Release/AgentMonitor.app
```

## What You'll See

The app shows a beautiful dashboard with:

- **Green cards** = Agents currently working
- **Red cards** = Failed agents that need attention  
- **Blue cards** = Completed agents

Each card displays:
- Agent session ID
- GitHub issue number
- Task description
- How long it's been running
- Current status

**Click any agent card** to see its full log output in real-time!

## Auto-Refresh

The app automatically refreshes every 3 seconds, so you always see the latest status.

## Troubleshooting

**"Xcode is required"**
- Install Xcode from the Mac App Store
- It's free and only takes a few minutes

**"No active agents"**
- Make sure your agents are running
- The app monitors `openclaw process list`
- Start some agents and they'll appear automatically

**App won't open**
- Right-click → Open (macOS may block unsigned apps)
- Or: System Settings → Privacy & Security → Allow

---

Enjoy stress-free agent monitoring! 🎉

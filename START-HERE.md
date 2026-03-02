# 👋 Start Here!

Welcome to **Agent Monitor** - your beautiful new dashboard for monitoring Claude Code agents!

## 🚀 Quick Start (3 Steps)

### 1. Open in Xcode
```bash
cd ~/Dev/tools/agent-monitor
./open-in-xcode.sh
```

### 2. Click the Play Button
Wait for Xcode to load, then click **▶️** (or press `⌘R`)

### 3. Watch Your Agents!
The app will launch and immediately show all your active agents working on the Roblox game.

---

## 💡 What You'll See

### Agent Cards
Each agent appears as a beautiful card showing:
- 🆔 **Session ID** (e.g., "briny-zephyr")
- 🎯 **GitHub Issue** (e.g., "#80")
- 📝 **Task Description** (what it's doing)
- ⏱️ **Duration** (how long it's been running)
- 🚦 **Status** (Green=running, Red=failed, Blue=done)

### Real-Time Updates
- Auto-refreshes every 3 seconds
- Shows "just now" / "5s ago" / "2m ago" updates
- Green pulse = actively monitoring

### Click for Logs
**Tap any agent card** to see its full log output in a beautiful modal window!

---

## 📚 More Info

- **README.md** - Complete feature list and documentation
- **QUICKSTART.md** - Step-by-step instructions
- **SUMMARY.md** - Technical details and architecture
- **verify.sh** - Check that everything is installed correctly

---

## 🎯 Why This App?

**Before:** 😰 "I'm blind and scared when agents are working"

**After:** 😎 Beautiful real-time dashboard showing exactly what's happening

---

## 🛠️ Need Help?

**App won't build?**
- Make sure Xcode is installed (Mac App Store)
- Try: `./verify.sh` to check installation

**No agents showing?**
- Make sure your agents are actually running
- Try: `openclaw process list` in terminal

**Want to customize?**
- All the code is yours to modify!
- SwiftUI makes it easy to change colors, layouts, etc.

---

## 🎉 You're All Set!

Run `./open-in-xcode.sh` and enjoy your new agent monitoring dashboard!

Built with ❤️ for stress-free autonomous coding.

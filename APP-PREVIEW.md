# 🎨 App Preview

## What Agent Monitor Looks Like

```
╔════════════════════════════════════════════════════════════════╗
║  🧠 Agent Monitor                                    🟢 just now ║
║  Roblox: Mine for Brainrots                              ⟳     ║
╠════════════════════════════════════════════════════════════════╣
║                                                                ║
║  ┌──────────────────────────────────────────────────────────┐ ║
║  │  🟢  briny-zephyr              #80               9m02s   │ ║
║  │                                                           │ ║
║  │      Fix GitHub issue: Implement depth limit             │ ║
║  │      Running                                          ›   │ ║
║  └──────────────────────────────────────────────────────────┘ ║
║                                                                ║
║  ┌──────────────────────────────────────────────────────────┐ ║
║  │  🟢  neat-seaslug               #83               9m02s   │ ║
║  │                                                           │ ║
║  │      Fix GitHub issue: Add cache persist                 │ ║
║  │      Running                                          ›   │ ║
║  └──────────────────────────────────────────────────────────┘ ║
║                                                                ║
║  ┌──────────────────────────────────────────────────────────┐ ║
║  │  🟢  keen-cove                  #88               9m02s   │ ║
║  │                                                           │ ║
║  │      Fix GitHub issue: Implement admin auth              │ ║
║  │      Running                                          ›   │ ║
║  └──────────────────────────────────────────────────────────┘ ║
║                                                                ║
║  ┌──────────────────────────────────────────────────────────┐ ║
║  │  🔴  delta-cloud                #80                  23s  │ ║
║  │                                                           │ ║
║  │      Fix GitHub issue: Implement depth limit             │ ║
║  │      Failed                                           ›   │ ║
║  └──────────────────────────────────────────────────────────┘ ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
```

## Key Visual Features

### 🎨 Color Coding
- **Green** cards with 🟢 icon = Agent actively working
- **Red** cards with 🔴 icon = Agent failed, needs attention
- **Blue** cards with 🔵 icon = Agent completed successfully

### 📊 Information Hierarchy
1. **Top line:** Agent ID + Issue number + Duration badge
2. **Middle:** Human-readable task description
3. **Bottom:** Status indicator
4. **Right:** Chevron (›) indicates clickable

### ⚡ Real-Time Elements
- **Live status indicator** in header (🟢 green = connected)
- **Timestamp** shows "just now", "5s ago", "2m ago"
- **Refresh button** (⟳) for manual updates
- **Auto-refresh** every 3 seconds

### 🖱️ Interactive
- **Click any card** → Opens full log viewer
- **Scroll** → View all agents (if more than fit on screen)
- **Refresh button** → Instant update

## Log Viewer Modal

When you click an agent:

```
╔════════════════════════════════════════════════════════════════╗
║  briny-zephyr                                         [ Done ] ║
║  Fix GitHub issue: Implement depth limit                       ║
╠════════════════════════════════════════════════════════════════╣
║                                                                ║
║  [2026-02-27 14:04:32] Starting agent...                      ║
║  [2026-02-27 14:04:33] Analyzing issue #80                    ║
║  [2026-02-27 14:04:35] Reading codebase structure             ║
║  [2026-02-27 14:05:12] Implementing depth limit check         ║
║  [2026-02-27 14:07:45] Writing tests...                       ║
║  [2026-02-27 14:09:22] Running test suite...                  ║
║  [2026-02-27 14:11:08] All tests passing ✓                    ║
║                                                                ║
║  [Full scrollable log output in monospaced font]              ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
```

## Design Philosophy

### ✨ Beautiful & Minimal
- Clean, uncluttered layout
- Ample whitespace
- Clear visual hierarchy
- Native macOS feel

### 🎯 Information Dense (But Not Overwhelming)
- Shows exactly what you need
- Everything important is visible
- Details available on-demand (click for logs)

### 🚀 Fast & Responsive
- Instant visual feedback
- Smooth animations
- No loading delays
- Lightweight (~2MB app)

### 💎 Polish & Attention to Detail
- Subtle shadows on cards
- Status-specific color tinting
- Smart text truncation
- Proper monospaced fonts for code/logs

---

**Note:** This is a text representation. The actual app uses SwiftUI for smooth animations, native macOS styling, and crisp rendering on Retina displays!

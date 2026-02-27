#!/bin/bash

clear

cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║              🧠  AGENT MONITOR - QUICK LAUNCHER              ║
║                                                               ║
║         Monitor your Claude Code agents in real-time!        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

EOF

echo "Choose how you want to launch Agent Monitor:"
echo ""
echo "  1) Open in Xcode (recommended for first time)"
echo "  2) Build from command line"
echo "  3) Verify installation"
echo "  4) Read documentation"
echo "  5) Exit"
echo ""
read -p "Enter choice (1-5): " choice

case $choice in
    1)
        echo ""
        echo "🚀 Opening Xcode..."
        ./open-in-xcode.sh
        ;;
    2)
        echo ""
        echo "🔨 Building..."
        ./build.sh
        ;;
    3)
        echo ""
        ./verify.sh
        ;;
    4)
        echo ""
        echo "📚 Opening documentation..."
        echo ""
        echo "Available guides:"
        echo "  - START-HERE.md       (Quick welcome)"
        echo "  - QUICKSTART.md       (Step-by-step)"
        echo "  - README.md           (Full features)"
        echo "  - SUMMARY.md          (Technical details)"
        echo "  - APP-PREVIEW.md      (What it looks like)"
        echo "  - COMPLETION-REPORT.md (Build details)"
        echo ""
        read -p "Open START-HERE.md? (y/n): " open_doc
        if [ "$open_doc" = "y" ] || [ "$open_doc" = "Y" ]; then
            open START-HERE.md
        fi
        ;;
    5)
        echo ""
        echo "👋 Goodbye!"
        exit 0
        ;;
    *)
        echo ""
        echo "❌ Invalid choice. Please run again and choose 1-5."
        exit 1
        ;;
esac

echo ""
echo "✅ Done!"
echo ""

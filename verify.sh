#!/bin/bash

echo "🔍 Verifying Agent Monitor installation..."
echo ""

errors=0

# Check critical files
files=(
    "AgentMonitor.xcodeproj/project.pbxproj"
    "AgentMonitor/AgentMonitorApp.swift"
    "AgentMonitor/ContentView.swift"
    "AgentMonitor/AgentMonitor.swift"
    "AgentMonitor/AgentMonitor.entitlements"
    "AgentMonitor/Assets.xcassets/Contents.json"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ MISSING: $file"
        errors=$((errors + 1))
    fi
done

echo ""

# Check if openclaw is accessible
if command -v openclaw &> /dev/null; then
    echo "✅ openclaw command found"
else
    echo "⚠️  WARNING: openclaw not in PATH"
    echo "   The app may not work without it"
fi

echo ""

if [ $errors -eq 0 ]; then
    echo "✅ All checks passed!"
    echo ""
    echo "Ready to run! Use one of:"
    echo "  ./open-in-xcode.sh    # Open in Xcode (recommended)"
    echo "  ./build.sh            # Build from command line"
    echo "  ./run.sh              # Build and run"
else
    echo "❌ Found $errors error(s)"
    echo "   Some files are missing. Please check the installation."
fi

echo ""

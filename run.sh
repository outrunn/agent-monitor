#!/bin/bash

echo "🚀 Launching Agent Monitor..."
echo ""

# Check if the app is already built
if [ -d "build/Build/Products/Release/AgentMonitor.app" ]; then
    echo "Opening existing build..."
    open build/Build/Products/Release/AgentMonitor.app
else
    echo "App not built yet. Building now..."
    ./build.sh
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "Opening app..."
        open build/Build/Products/Release/AgentMonitor.app
    fi
fi

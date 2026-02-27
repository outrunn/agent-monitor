#!/bin/bash

set -e

echo "🔨 Building Agent Monitor..."

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo ""
    echo "❌ Xcode is required to build this app"
    echo ""
    echo "To install Xcode:"
    echo "  1. Open Mac App Store"
    echo "  2. Search for 'Xcode'"
    echo "  3. Click 'Get' or 'Install'"
    echo ""
    echo "After installing Xcode, run this script again."
    exit 1
fi

# Build the app
echo "Building..."
xcodebuild -project AgentMonitor.xcodeproj \
  -scheme AgentMonitor \
  -configuration Release \
  -derivedDataPath ./build \
  clean build

echo ""
echo "✅ Build complete!"
echo ""
echo "To run the app:"
echo "  open build/Build/Products/Release/AgentMonitor.app"
echo ""

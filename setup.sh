#!/bin/bash
set -e

echo "Setting up Sprout..."

if ! command -v xcodegen &> /dev/null; then
    echo "Installing xcodegen..."
    brew install xcodegen
fi

xcodegen generate
echo ""
echo "Done. Open Sprout.xcodeproj in Xcode and hit Run (Cmd+R)."
echo "Sprout will appear as a colored dot in your menu bar."

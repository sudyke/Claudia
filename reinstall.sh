#!/usr/bin/env bash
# Build Release and reinstall Claudia.app to /Applications.
# Use this after code changes to refresh the installed copy.

set -euo pipefail

cd "$(dirname "$0")"

echo "→ Building Release..."
xcodebuild \
    -project Claudia.xcodeproj \
    -scheme Claudia \
    -configuration Release \
    -derivedDataPath build \
    clean build \
    | xcbeautify 2>/dev/null || xcodebuild \
        -project Claudia.xcodeproj \
        -scheme Claudia \
        -configuration Release \
        -derivedDataPath build \
        clean build \
        | tail -20

echo "→ Stopping running instance (if any)..."
killall Claudia 2>/dev/null || true

echo "→ Replacing /Applications/Claudia.app..."
rm -rf /Applications/Claudia.app
cp -R build/Build/Products/Release/Claudia.app /Applications/

echo "→ Launching..."
open /Applications/Claudia.app

echo "✓ Done. Claudia is running."

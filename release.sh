#!/usr/bin/env bash
# Build Claudia.app for Release, package as a signed .dmg, output to ./dist/.
# Ad-hoc signed (no Apple Developer ID). Users see Gatekeeper warning on first launch.

set -euo pipefail

cd "$(dirname "$0")"

VERSION="${1:?Usage: ./release.sh <version>  e.g. ./release.sh 0.1.0}"
APP_NAME="Claudia"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
BUILD_DIR="build"
DIST_DIR="dist"
APP_PATH="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"

echo "→ Building Release configuration..."
xcodebuild \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}" \
    clean build \
    > "${BUILD_DIR}.log" 2>&1 || (tail -30 "${BUILD_DIR}.log" && exit 1)

if [ ! -d "${APP_PATH}" ]; then
    echo "✗ Expected ${APP_PATH} not found after build"
    exit 1
fi

echo "→ Ad-hoc signing the app..."
codesign --force --deep --sign - "${APP_PATH}"

mkdir -p "${DIST_DIR}"
rm -f "${DIST_DIR}/${DMG_NAME}"

echo "→ Packaging ${DMG_NAME}..."
create-dmg \
    --volname "${APP_NAME} ${VERSION}" \
    --window-pos 200 120 \
    --window-size 540 360 \
    --icon-size 96 \
    --icon "${APP_NAME}.app" 140 180 \
    --app-drop-link 400 180 \
    --no-internet-enable \
    "${DIST_DIR}/${DMG_NAME}" \
    "${APP_PATH}" \
    > /dev/null

echo "✓ Built ${DIST_DIR}/${DMG_NAME}"
ls -lh "${DIST_DIR}/${DMG_NAME}"

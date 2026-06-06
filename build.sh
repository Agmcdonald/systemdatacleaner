#!/bin/bash
#
# build.sh — assemble SystemDataCleaner.app from src/ and zip it for sharing.
# Output: build/SystemDataCleaner.app and build/SystemDataCleaner.zip
#
set -euo pipefail
cd "$(dirname "$0")"

APP="build/SystemDataCleaner.app"
echo "Cleaning previous build..."
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "Assembling app bundle..."
cp src/SystemDataCleaner "$APP/Contents/MacOS/SystemDataCleaner"
chmod +x "$APP/Contents/MacOS/SystemDataCleaner"
cp Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "Zipping..."
( cd build && zip -r -y -X SystemDataCleaner.zip SystemDataCleaner.app >/dev/null )

echo "Done:"
echo "  $APP"
echo "  build/SystemDataCleaner.zip"

#!/bin/bash
set -e

APP="Stretchy.app"
echo "🐱 Building Stretchy..."

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

swiftc Sources/Stretchy/*.swift \
    -o "$APP/Contents/MacOS/Stretchy"

cp Sources/Stretchy/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc sign so macOS allows it to run
codesign --force --deep --sign - "$APP" 2>/dev/null || true

echo ""
echo "✅ Done!  Run it:"
echo "   open $APP"
echo ""
echo "First launch: if macOS blocks it, right-click → Open in Finder."

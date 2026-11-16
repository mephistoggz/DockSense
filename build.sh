#!/bin/sh
set -eu
cd "$(dirname "$0")"
if ! xcrun --find clang >/dev/null 2>&1; then
    echo 'Apple Command Line Tools gerekli. Kurulum: xcode-select --install' >&2
    exit 1
fi
mkdir -p build
stage=$(mktemp -d "$PWD/build/.stage.XXXXXX")
cleanup() {
    if [ -d "$stage/previous.app" ] && [ ! -e build/DockSense.app ]; then
        mv "$stage/previous.app" build/DockSense.app
    fi
    rm -rf "$stage"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
app="$stage/DockSense.app"
mkdir -p "$app/Contents/MacOS"
xcrun clang -fobjc-arc -O2 -Wall -Wextra -Werror \
    -arch x86_64 -arch arm64 -mmacosx-version-min=11.0 \
    -framework Cocoa -framework ApplicationServices \
    main.m -o "$app/Contents/MacOS/DockSense"
cp Info.plist "$app/Contents/Info.plist"
plutil -lint "$app/Contents/Info.plist"
xcrun lipo -verify_arch x86_64 arm64 "$app/Contents/MacOS/DockSense"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
if [ -e build/DockSense.app ]; then mv build/DockSense.app "$stage/previous.app"; fi
mv "$app" build/DockSense.app
echo 'Hazır: build/DockSense.app'

#!/bin/sh
set -eu
cd "$(dirname "$0")"
if ! xcrun --find clang >/dev/null 2>&1; then
    echo 'Apple Command Line Tools gerekli. Kurulum: xcode-select --install' >&2
    exit 1
fi
mkdir -p build
# Sign outside cloud-synced folders, which may attach FinderInfo to .app bundles.
stage=$(mktemp -d "${TMPDIR:-/tmp}/DockSense-build.XXXXXX")
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
# Copy file contents only: Finder metadata from a downloaded source tree can
# otherwise make codesign reject the newly generated application.
cat Info.plist > "$app/Contents/Info.plist"
plutil -lint "$app/Contents/Info.plist"
xcrun lipo "$app/Contents/MacOS/DockSense" -verify_arch x86_64 arm64
codesign --force --sign - "$app"
codesign --verify --strict "$app"
if [ -e build/DockSense.app ]; then mv build/DockSense.app "$stage/previous.app"; fi
mv "$app" build/DockSense.app
# A file provider can add cosmetic FinderInfo again during the move. Remove
# only that attribute, never quarantine/provenance or other security metadata.
if xattr -p com.apple.FinderInfo build/DockSense.app >/dev/null 2>&1; then
    xattr -d com.apple.FinderInfo build/DockSense.app
fi
if ! codesign --verify --strict build/DockSense.app; then
    rm -rf build/DockSense.app
    exit 1 # cleanup restores the previous application
fi
echo 'Hazır: build/DockSense.app'

#!/bin/sh
# Exercise the real build script's failure paths without invoking a compiler.
set -eu
cd "$(dirname "$0")/.."
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -p "$temp/bin" "$temp/project/build/DockSense.app"
mkdir -p "$temp/staging"
export TMPDIR="$temp/staging"
cp build.sh Info.plist main.m Policy.h "$temp/project/"
printf 'previous working app\n' > "$temp/project/build/DockSense.app/sentinel"
cat > "$temp/bin/xcrun" <<'EOF'
#!/bin/sh
if [ "$1" = --find ]; then
    [ "${FAIL_STAGE:-}" != missing ]
elif [ "$1" = clang ]; then
    [ "${FAIL_STAGE:-}" != compile ] || exit 1
    while [ "$#" -gt 0 ]; do
        if [ "$1" = -o ]; then shift; printf 'mock binary\n' > "$1"; exit 0; fi
        shift
    done
    exit 1
elif [ "$1" = lipo ]; then
    [ "$#" -eq 5 ] && [ -f "$2" ] && [ "$3" = -verify_arch ] && [ "$4" = x86_64 ] && [ "$5" = arm64 ] || exit 1
    [ "${FAIL_STAGE:-}" != architecture ]
else
    exit 1
fi
EOF
cat > "$temp/bin/codesign" <<'EOF'
#!/bin/sh
case "$1" in
    --force) [ "${FAIL_STAGE:-}" != sign ] ;;
    --verify) [ "${FAIL_STAGE:-}" != verify ] ;;
    *) exit 1 ;;
esac
EOF
chmod +x "$temp/bin/xcrun" "$temp/bin/codesign"
export PATH="$temp/bin:$PATH"
for stage in missing compile architecture sign verify; do
    if FAIL_STAGE="$stage" sh "$temp/project/build.sh" > "$temp/log" 2>&1; then
        echo "FAIL: $stage should fail" >&2; exit 1
    fi
    test "$(cat "$temp/project/build/DockSense.app/sentinel")" = 'previous working app'
    if find "$temp/staging" -name 'DockSense-build.*' | /usr/bin/grep -q .; then
        echo 'FAIL: staging directory leaked' >&2; exit 1
    fi
    echo "PASS: $stage failure preserves previous application"
done
FAIL_STAGE= sh "$temp/project/build.sh" > "$temp/log" 2>&1
test -f "$temp/project/build/DockSense.app/Contents/MacOS/DockSense"
test ! -f "$temp/project/build/DockSense.app/sentinel"
echo 'PASS: successful build replaces previous application'

#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
xcrun clang -std=c11 -Wall -Wextra -Werror tests/policy_test.c -o "$temp/policy_test"
"$temp/policy_test"
sh -n build.sh
plutil -lint Info.plist
sh tests/build_safety.sh
sh build.sh
echo 'Politika testleri, universal derleme ve imza kontrolü geçti.'

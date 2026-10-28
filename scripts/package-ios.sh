#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/version.sh"

app=build/ios/iphoneos/Runner.app
test -d "$app"
mkdir -p release
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/Payload"
ditto "$app" "$stage/Payload/Runner.app"
output="$PWD/release/fuckxter-${APP_VERSION}-${APP_BUILD}-ios.ipa"
(cd "$stage" && /usr/bin/zip -qr "$output" Payload)
unzip -l "$output" | grep -F 'Payload/Runner.app/'
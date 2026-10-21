#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/version.sh"
app=build/macos/Build/Products/Release/fuckxter_app.app
plist="$app/Contents/Info.plist"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")" = "$APP_VERSION"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")" = "$APP_BUILD"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/FuckXter.app"
ln -s /Applications "$stage/Applications"
mkdir -p release
dmg="release/fuckxter-${APP_VERSION}-${APP_BUILD}-macos-$(uname -m).dmg"
hdiutil create -volname "FuckXter $APP_VERSION" -srcfolder "$stage" -ov -format UDZO "$dmg"
hdiutil verify "$dmg"

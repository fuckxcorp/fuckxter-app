#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/version.sh"
export GLIBC_VERSION
GLIBC_VERSION=$(getconf GNU_LIBC_VERSION | cut -d' ' -f2)
name="fuckxter-${APP_VERSION}-${APP_BUILD}-linux-x86_64"
mkdir -p release
for format in deb rpm archlinux; do
  case "$format" in
    archlinux) suffix=pkg.tar.zst ;;
    *) suffix=$format ;;
  esac
  nfpm package --config packaging/linux/nfpm.yaml --packager "$format" --target "release/$name.$suffix"
done

test "$(dpkg-deb -f "release/$name.deb" Version)" = "$APP_VERSION-$APP_BUILD"
test "$(rpm -qp --queryformat '%{VERSION}-%{RELEASE}' "release/$name.rpm")" = "$APP_VERSION-$APP_BUILD"
tar --zstd -xOf "release/$name.pkg.tar.zst" .PKGINFO | grep -Fx "pkgver = $APP_VERSION-$APP_BUILD"
sudo dpkg --install "release/$name.deb"
test -x /usr/bin/fuckxter
test -f /opt/fuckxter/data/icudtl.dat

appdir="$PWD/build/AppDir"
mkdir -p "$appdir/usr/lib/fuckxter" "$appdir/usr/bin"
cp -a build/linux/x64/release/bundle/. "$appdir/usr/lib/fuckxter/"
ln -s ../lib/fuckxter/fuckxter_app "$appdir/usr/bin/fuckxter"
chmod +x packaging/linux/AppRun
curl --fail --location --retry 3 https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage -o build/linuxdeploy.AppImage
chmod +x build/linuxdeploy.AppImage
export ARCH=x86_64
export OUTPUT="$PWD/release/$name.AppImage"
APPIMAGE_EXTRACT_AND_RUN=1 build/linuxdeploy.AppImage --appdir "$appdir" \
  --deploy-deps-only "$appdir/usr/lib/fuckxter" \
  --deploy-deps-only "$appdir/usr/lib/fuckxter/lib" \
  --desktop-file packaging/linux/fuckxter.desktop \
  --icon-file macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png \
  --icon-filename fuckxter \
  --custom-apprun packaging/linux/AppRun --output appimage
chmod +x "$OUTPUT"
mkdir -p build/appimage-check
(cd build/appimage-check && "$OUTPUT" --appimage-extract > /dev/null)
test -x build/appimage-check/squashfs-root/AppRun
test -x build/appimage-check/squashfs-root/usr/lib/fuckxter/fuckxter_app
if ldd build/appimage-check/squashfs-root/usr/lib/fuckxter/fuckxter_app | grep 'not found'; then
  exit 1
fi

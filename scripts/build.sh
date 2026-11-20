#!/usr/bin/env bash
#
# Builds "No Drag Release Delay.app".
#
#   scripts/build.sh [arm64|x86_64|universal] [--install]
#
# Output: build/<arch>/No Drag Release Delay.app
#
# Signing: ad-hoc by default. Set CODESIGN_IDENTITY to a Developer ID to produce
# a hardened-runtime build that survives notarisation.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAME="No Drag Release Delay"
EXECUTABLE="NoDragReleaseDelay"
BUNDLE_ID="com.amiralimanzar3.NoDragReleaseDelay"
MIN_MACOS="13.0"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"

ARCH="universal"
INSTALL=0
for arg in "$@"; do
    case "$arg" in
        arm64|x86_64|universal) ARCH="$arg" ;;
        --install)              INSTALL=1 ;;
        *) echo "usage: $0 [arm64|x86_64|universal] [--install]" >&2; exit 1 ;;
    esac
done

case "$ARCH" in
    arm64|x86_64) TARGETS=("$ARCH") ;;
    universal)    TARGETS=(arm64 x86_64) ;;
esac

BUILD="$ROOT/build/$ARCH"
APP="$BUILD/$NAME.app"
SOURCES=()
while IFS= read -r file; do SOURCES+=("$file"); done < <(find "$ROOT/Sources" -name '*.swift' | sort)

rm -rf "$BUILD"
mkdir -p "$BUILD" "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "==> Compiling $ARCH ($VERSION)"
SLICES=()
for target in "${TARGETS[@]}"; do
    echo "    $target"
    xcrun swiftc -O -wmo -target "$target-apple-macos$MIN_MACOS" \
        -o "$BUILD/$EXECUTABLE-$target" \
        "${SOURCES[@]}"
    SLICES+=("$BUILD/$EXECUTABLE-$target")
done

if [ "${#SLICES[@]}" -gt 1 ]; then
    lipo -create -output "$APP/Contents/MacOS/$EXECUTABLE" "${SLICES[@]}"
else
    cp "${SLICES[0]}" "$APP/Contents/MacOS/$EXECUTABLE"
fi
rm -f "$BUILD/$EXECUTABLE"-*

echo "==> Assembling bundle"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

if [ ! -f "$ROOT/Resources/AppIcon.icns" ]; then
    echo "==> Rendering icon"
    ICONSET="$BUILD/AppIcon.iconset"
    rm -rf "$ICONSET"
    mkdir -p "$ICONSET"
    xcrun swift "$ROOT/tools/makeicon.swift" "$BUILD/icon.png" >/dev/null
    for size in 16 32 128 256 512; do
        sips -z "$size" "$size" "$BUILD/icon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
        retina=$((size * 2))
        sips -z "$retina" "$retina" "$BUILD/icon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$ROOT/Resources/AppIcon.icns"
fi
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# Stray extended attributes turn into AppleDouble entries inside a .pkg payload.
xattr -cr "$APP"

echo "==> Signing"
if [ -n "${CODESIGN_IDENTITY:-}" ]; then
    codesign --force --options runtime --timestamp \
        --sign "$CODESIGN_IDENTITY" --identifier "$BUNDLE_ID" "$APP"
else
    codesign --force --sign - --identifier "$BUNDLE_ID" --timestamp=none "$APP"
fi
codesign --verify --strict "$APP"

echo
echo "Built  $APP"
echo "Arch   $(lipo -archs "$APP/Contents/MacOS/$EXECUTABLE")"

if [ "$INSTALL" -eq 1 ]; then
    echo "==> Installing to /Applications"
    pkill -x "$EXECUTABLE" 2>/dev/null || true
    sleep 1
    rm -rf "/Applications/$NAME.app"
    ditto "$APP" "/Applications/$NAME.app"
    open "/Applications/$NAME.app"
fi

#!/usr/bin/env bash
#
# Produces the release artifacts:
#
#   dist/NoDragReleaseDelay-<version>-arm64.pkg      Apple Silicon installer
#   dist/NoDragReleaseDelay-<version>-x86_64.pkg     Intel installer
#   dist/NoDragReleaseDelay-<version>-universal.dmg  drag-to-Applications
#   dist/SHA256SUMS
#
# Set CODESIGN_IDENTITY to sign with a Developer ID instead of ad-hoc.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAME="No Drag Release Delay"
BUNDLE_ID="com.amiralimanzar3.NoDragReleaseDelay"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
DIST="$ROOT/dist"

rm -rf "$DIST"
mkdir -p "$DIST"

for arch in arm64 x86_64; do
    echo "==> $arch"
    "$ROOT/scripts/build.sh" "$arch" >/dev/null

    STAGE="$(mktemp -d)"
    mkdir -p "$STAGE/Applications"
    ditto "$ROOT/build/$arch/$NAME.app" "$STAGE/Applications/$NAME.app"

    pkgbuild \
        --root "$STAGE" \
        --scripts "$ROOT/scripts/pkg" \
        --identifier "$BUNDLE_ID" \
        --version "$VERSION" \
        --install-location "/" \
        "$DIST/NoDragReleaseDelay-$VERSION-$arch.pkg"

    rm -rf "$STAGE"
done

echo "==> universal"
"$ROOT/scripts/build.sh" universal >/dev/null

STAGE="$ROOT/build/dmg"
rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto "$ROOT/build/universal/$NAME.app" "$STAGE/$NAME.app"
ln -s /Applications "$STAGE/Applications"

hdiutil create \
    -volname "$NAME" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DIST/NoDragReleaseDelay-$VERSION-universal.dmg" >/dev/null

echo "==> checksums"
(cd "$DIST" && shasum -a 256 *.pkg *.dmg > SHA256SUMS)

ls -lh "$DIST"

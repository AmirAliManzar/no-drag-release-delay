#!/usr/bin/env bash
#
# Produces the release artifacts:
#
#   dist/NoDragReleaseDelay-<version>-arm64.pkg      Apple Silicon installer
#   dist/NoDragReleaseDelay-<version>-x86_64.pkg     Intel installer
#   dist/NoDragReleaseDelay-<version>-arm64.dmg      Apple Silicon, drag to Applications
#   dist/NoDragReleaseDelay-<version>-x86_64.dmg     Intel, drag to Applications
#   dist/SHA256SUMS
#
# Artifacts are per-architecture on purpose: a universal binary carries an
# Intel slice that macOS warns about on Apple Silicon, and the two builds are
# otherwise identical.
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
    APP="$ROOT/build/$arch/$NAME.app"

    STAGE="$(mktemp -d)"
    mkdir -p "$STAGE/Applications"
    ditto "$APP" "$STAGE/Applications/$NAME.app"

    pkgbuild \
        --root "$STAGE" \
        --scripts "$ROOT/scripts/pkg" \
        --identifier "$BUNDLE_ID" \
        --version "$VERSION" \
        --install-location "/" \
        "$DIST/NoDragReleaseDelay-$VERSION-$arch.pkg"

    rm -rf "$STAGE"

    STAGE="$ROOT/build/dmg-$arch"
    rm -rf "$STAGE"
    mkdir -p "$STAGE"
    ditto "$APP" "$STAGE/$NAME.app"
    ln -s /Applications "$STAGE/Applications"

    hdiutil create \
        -volname "$NAME" \
        -srcfolder "$STAGE" \
        -ov -format UDZO \
        "$DIST/NoDragReleaseDelay-$VERSION-$arch.dmg" >/dev/null
done

echo "==> checksums"
(cd "$DIST" && shasum -a 256 *.pkg *.dmg > SHA256SUMS)

ls -lh "$DIST"

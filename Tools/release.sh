#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export ONDE_BUILD="${ONDE_BUILD:-$(date -u +%Y%m%d%H%M%S)}"
export ONDE_COMMIT="${GITHUB_SHA:-$(git rev-parse HEAD)}"
VERSION=$(cat VERSION)
TAG="build-$ONDE_BUILD-${ONDE_COMMIT:0:8}"
# Tests run natively. The other architecture is cross-compiled against the macOS SDK.
swift test -c release -j 3
native=$(uname -m)
if [[ "$native" == arm64 ]]; then other=x86_64; else other=arm64; fi
swift build -c release --triple "$other-apple-macosx14.0" --scratch-path .build-cross -j 3
cross=$(swift build -c release --triple "$other-apple-macosx14.0" --scratch-path .build-cross --show-bin-path)
mkdir -p .build/universal dist
for name in Onde ondectl; do
  lipo -create ".build/release/$name" "$cross/$name" -output ".build/universal/$name"
  lipo ".build/universal/$name" -verify_arch arm64 x86_64
done
ONDE_BIN_DIR="$PWD/.build/universal" bash Tools/package.sh
codesign --verify --deep --strict dist/Onde.app
/usr/libexec/PlistBuddy -c 'Print :OndeCommit' dist/Onde.app/Contents/Info.plist
COPYFILE_DISABLE=1 ditto -c -k --keepParent --norsrc dist/Onde.app dist/Onde-macOS-universal.zip
(cd dist && shasum -a 256 Onde-macOS-universal.zip > Onde-macOS-universal.zip.sha256)
# Audition files use the same just-built DSP and documented profile settings.
for profile in elan reacteur traction; do
  .build/release/ondectl generate render "$profile" "$PWD/dist/$profile-5min.wav" --minutes 5
  /usr/bin/afconvert -f m4af -d aac -b 256000 "dist/$profile-5min.wav" "dist/$profile-5min.m4a"
done
printf 'TAG=%s\nVERSION=%s\nONDE_BUILD=%s\n' "$TAG" "$VERSION" "$ONDE_BUILD" > dist/release.env
cat > dist/release-notes.md <<EOF
## Onde $VERSION

Native macOS app, universal binary for Apple Silicon and Intel (macOS 14+).
Built from commit $ONDE_COMMIT after all unit tests passed.

Download **Onde-macOS-universal.zip**, unzip, quit the old app and move Onde.app into Applications.
Personal settings, saved soundscapes and imports are stored separately and are preserved.

This community build is ad-hoc signed, **not notarized by Apple**. No security settings are changed.
The app checks public GitHub releases and offers a SHA-256-verified download; installation remains manual.

Only original procedural audio is bundled in this automated release. No Endel audio or personal imports.
EOF

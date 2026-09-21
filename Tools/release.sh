#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export ONDE_BUILD="${ONDE_BUILD:-$(date -u +%Y%m%d%H%M%S)}"
export ONDE_COMMIT="${GITHUB_SHA:-$(git rev-parse HEAD)}"
VERSION=$(cat VERSION)
TAG="build-$ONDE_BUILD-${ONDE_COMMIT:0:8}"
python3 Tools/check_english.py
bash Tools/prepare_orchestra.sh
# Tests run natively. The other architecture is cross-compiled against the macOS SDK.
swift test -c release -j 3
native=$(uname -m)
if [[ "$native" == arm64 ]]; then other=x86_64; else other=arm64; fi
swift build -c release --triple "$other-apple-macosx14.0" --scratch-path .build-cross -j 3
cross=$(swift build -c release --triple "$other-apple-macosx14.0" --scratch-path .build-cross --show-bin-path)
mkdir -p .build/universal dist
for name in Onde ondectl onde-updater; do
  lipo -create ".build/release/$name" "$cross/$name" -output ".build/universal/$name"
  lipo ".build/universal/$name" -verify_arch arm64 x86_64
done
ONDE_BIN_DIR="$PWD/.build/universal" bash Tools/package.sh
codesign --verify --deep --strict dist/Onde.app
# The bundled CLI must report the same version as the archive and release.
REPORTED_VERSION=$(dist/Onde.app/Contents/MacOS/ondectl schema | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["version"])')
[[ "$REPORTED_VERSION" == "$VERSION" ]] || { echo 'Packaged CLI version mismatch' >&2; exit 1; }
/usr/libexec/PlistBuddy -c 'Print :OndeCommit' dist/Onde.app/Contents/Info.plist
COPYFILE_DISABLE=1 ditto -c -k --keepParent --norsrc dist/Onde.app dist/Onde-macOS-universal.zip
(cd dist && shasum -a 256 Onde-macOS-universal.zip > Onde-macOS-universal.zip.sha256)
ONDE_PACKAGED_UPDATE_ARCHIVE="$PWD/dist/Onde-macOS-universal.zip" swift test -c release -j 3 --filter testPackagedUpdateArchiveIsAccepted
# Audition files use the same just-built DSP and documented profile settings.
for profile in ambre canopee meridien sillage filigrane confluence sanctuaire lagoon stillwater hearth reverie driftwood; do
  .build/release/ondectl generate render "$profile" "$PWD/dist/$profile-12min.wav" --minutes 12
  /usr/bin/afconvert -f m4af -d aac -b 256000 "dist/$profile-12min.wav" "dist/$profile-12min.m4a"
done
.build/release/ondectl generate transition-render ambre sanctuaire "$PWD/dist/transition-ambre-sanctuaire.wav" --seconds 70 --at 25 --fade 10
/usr/bin/afconvert -f m4af -d aac -b 256000 dist/transition-ambre-sanctuaire.wav dist/transition-ambre-sanctuaire.m4a
printf 'TAG=%s\nVERSION=%s\nONDE_BUILD=%s\n' "$TAG" "$VERSION" "$ONDE_BUILD" > dist/release.env
cat > dist/release-notes.md <<EOF
## Onde $VERSION

Native macOS app, universal binary for Apple Silicon and Intel (macOS 14+).
Built from commit $ONDE_COMMIT after all unit tests passed.

Download **Onde-macOS-universal.zip**, unzip, quit the old app and move Onde.app into Applications.
Personal settings, saved soundscapes and imports are stored separately and are preserved.

This community build is ad-hoc signed, **not notarized by Apple**. No security settings are changed.
After a verified download, choose Install and Relaunch. Installation requires explicit approval.
Download-only clients (1.11.3 and earlier) need one manual replacement to receive this updater.
Future releases are built and published from main; no user Mac is needed for deployment.

Local audio only: no embedded external streaming player.
Fresh selection after pause starts only the chosen music; ordinary Play resumes.
Gentle start: eight-second configurable fade-in, two-second resume, unchanged live scene crossfades and chimes.
One listening screen with Focus, Relax and Meditation; independent default music for each.
Relax and Meditation share the same musical catalog. Optional white/pink/brown noise,
rain and ocean have independent levels. Backgrounds and music choices preserve timers.
Detailed sound controls and personal tools open only when requested.
English interface and corrected local-day accounting (including midnight, pause, reset and DST).
Five new Relax/Meditation pieces: Lagoon, Stillwater, Hearth, Reverie and Driftwood.
Separate authored scores, warm continuous synthesis, soft acoustic piano, legato chamber ensemble,
wordless synthesized choir and wooden resonators with harp. No new private or proprietary samples.
Existing default selections and all Focus scores are preserved.
Seven long-form Focus compositions: Amber, Canopy, Meridian, Slipstream, Filigree, Confluence and Sanctuary.
Twelve-minute audition recordings use this exact engine and its defaults.
Filigree uses recorded soft piano; Sanctuary uses original synthesized nonverbal vowels, not recordings of singers.
Stable CLI IDs, existing mixes, personal imports and chime settings are preserved.
Pre-1.9 historical day allocations are estimates because exact pause times were not saved.
The source is evidence-informed; these individual tracks have not been clinically validated.
Pinned, checksum-verified CC0 acoustic instrument bank (VSCO 2 CE). No commercial streaming recordings or personal imports.
EOF

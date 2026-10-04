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
ONDE_PACKAGED_APPLICATION="$PWD/dist/Onde.app" swift test -c release -j 3 --filter UpdatePackagedTests
# The bundled CLI must report the same version as the archive and release.
REPORTED_VERSION=$(dist/Onde.app/Contents/MacOS/ondectl schema | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["version"])')
[[ "$REPORTED_VERSION" == "$VERSION" ]] || { echo 'Packaged CLI version mismatch' >&2; exit 1; }
/usr/libexec/PlistBuddy -c 'Print :OndeCommit' dist/Onde.app/Contents/Info.plist
COPYFILE_DISABLE=1 ditto -c -k --keepParent --norsrc dist/Onde.app dist/Onde-macOS-universal.zip
(cd dist && shasum -a 256 Onde-macOS-universal.zip > Onde-macOS-universal.zip.sha256)
ONDE_PACKAGED_UPDATE_ARCHIVE="$PWD/dist/Onde-macOS-universal.zip" swift test -c release -j 3 --filter testPackagedUpdateArchiveIsAccepted
# Audition files use the same just-built DSP and documented profile settings.
for profile in ambre canopee meridien sillage filigrane confluence sanctuaire gravite orbite sonar lagoon stillwater hearth reverie driftwood; do
  .build/release/ondectl generate render "$profile" "$PWD/dist/$profile-12min.wav" --minutes 12
  /usr/bin/afconvert -f m4af -d aac -b 256000 "dist/$profile-12min.wav" "dist/$profile-12min.m4a"
done
.build/release/ondectl generate transition-render ambre sanctuaire "$PWD/dist/transition-ambre-sanctuaire.wav" --seconds 70 --at 25 --fade 10
/usr/bin/afconvert -f m4af -d aac -b 256000 dist/transition-ambre-sanctuaire.wav dist/transition-ambre-sanctuaire.m4a
printf 'TAG=%s\nVERSION=%s\nONDE_BUILD=%s\n' "$TAG" "$VERSION" "$ONDE_BUILD" > dist/release.env
cat > dist/release-notes.md <<EOF
## Onde $VERSION

Native macOS app, universal binary for Apple Silicon and Intel (macOS 14+).
Built from commit $ONDE_COMMIT. Publication requires the native UI, functional,
installation and cross-platform candidate gates to pass. The published ZIP is the
exact archive exercised by the compatibility jobs, not a later rebuild.

Download **Onde-macOS-universal.zip**, unzip, quit the old app and move Onde.app into Applications.
Personal settings, saved soundscapes and imports are stored separately and are preserved.

This community build is ad-hoc signed, **not notarized by Apple**. No security settings are changed.
After a verified download, choose Install and Relaunch. Installation requires explicit approval.
Download-only clients (1.11.3 and earlier) need one manual replacement to receive this updater.
Future releases are built and published from main; no user Mac is needed for deployment.

### New in 1.14.0

Sonar, the third bass-led Focus piece. The same rules as Gravity and Orbit in a stripped-back minimal deep-techno
style: a filtered bass line whose tone opens and closes over minutes while its notes stay the same, a dark drone,
distant pings and soft offbeat ticks. Gravity remains the Focus default; saved defaults and mixes are unchanged.

### New in 1.13.0

Orbit, the warm sibling of Gravity. The same rules (one beat-locked kick and sub, an offbeat bass, nothing sudden,
a fast tremolo on the chords that can be set to zero) in a deep house and dub style in A Dorian, with pumping organ
chords and soft electric piano echoes. Gravity remains the Focus default; saved defaults and mixes are unchanged.

### New in 1.12.0

Gravity, a bass-led Focus piece at 120 BPM. One beat-locked oscillator is both the soft kick and the sub;
an offbeat bass, slow chords and a few quiet notes sit above it. No drops, fills, samples or voice.
A fast tremolo on the chords can be set to zero. New installations start on Gravity in Focus; a Focus default you
already saved is kept (star Gravity to switch). Saved mixes and the 25 earlier pieces are unchanged.

### Performance in 1.11.7

Animated artwork now invalidates only its native drawing surface instead of the entire listening hierarchy.
The same 24 fps active animation, authored geometry and per-track identities are preserved.
Frame rendering batches paths directly without allocating thousands of temporary point objects per frame.
Hidden, minimized, occluded and settings-covered artwork still suspends its animation clock.
Audio preparation, transport timing, fades and the verified acoustic bank are unchanged.

### Reliability in 1.11.5

Saved-mix deletion targets exactly one identity; ambiguous names are rejected.
Clean settings sheets allow Quit, while unapplied chime times stay protected.
Chime players are released after completion; live master mute affects previews.
Malformed external controls are rejected before state changes.
Update checks have a short, separate metadata timeout and can recover after failure.
The bundled icon is cached before native alerts; no macOS service is reset.
Native actions and real text input are exercised alongside the functional suites.
Community-build and physical-device validation limits are documented in the repository.

### Listening

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
Ten long-form Focus compositions: Amber, Canopy, Meridian, Slipstream, Filigree, Confluence, Sanctuary, Gravity, Orbit and Sonar.
Twelve-minute audition recordings use this exact engine and its defaults.
Filigree uses recorded soft piano; Sanctuary uses original synthesized nonverbal vowels, not recordings of singers.
Stable CLI IDs, existing mixes, personal imports and chime settings are preserved.
Pre-1.9 historical day allocations are estimates because exact pause times were not saved.
The source is evidence-informed; these individual tracks have not been clinically validated.
Pinned, checksum-verified CC0 acoustic instrument bank (VSCO 2 CE). No commercial streaming recordings or personal imports.
EOF

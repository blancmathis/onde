#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
mkdir -p Assets .build/tools dist
if [[ ! -f Assets/.synth-v1 ]]; then
  swiftc -O Tools/Synthesize.swift -o .build/tools/synthesize
  .build/tools/synthesize "$ROOT/Assets"
  for name in aube piano orbit rain ocean brown pink chime; do
    /usr/bin/afconvert -f m4af -d aac -b 192000 "Assets/$name.wav" "Assets/$name.m4a"
  done
  touch Assets/.synth-v1
fi
python3 Tools/white_noise.py "$ROOT/Assets/white.wav"
if [[ "${ONDE_SKIP_DOWNLOADS:-0}" != "1" ]]; then
  python3 Tools/fetch_music.py "$ROOT/Assets"
fi
if [[ ! -f Assets/Orchestra/manifest.json ]]; then bash Tools/prepare_orchestra.sh; fi
APP="$ROOT/dist/Onde.app"
# Rebuild only our owned bundle to prevent stale/private assets leaking into a release.
if [[ -d "$APP" ]]; then
  ONDE_PACKAGE_PATH="$APP" python3 - <<'CLEAN'
import os, pathlib, plistlib, shutil
p=pathlib.Path(os.environ['ONDE_PACKAGE_PATH'])
assert p.name=='Onde.app' and p.parent.name=='dist'
info=plistlib.loads((p/'Contents/Info.plist').read_bytes())
assert info['CFBundleIdentifier']=='app.onde.mac'
shutil.rmtree(p)
CLEAN
fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Sounds"
cp "${ONDE_BIN_DIR:-.build/release}/Onde" "$APP/Contents/MacOS/Onde"
cp "${ONDE_BIN_DIR:-.build/release}/ondectl" "$APP/Contents/MacOS/ondectl"
cp Assets/white.wav "$APP/Contents/Resources/Sounds/"
for name in aube piano orbit rain ocean brown pink chime; do cp "Assets/$name.m4a" "$APP/Contents/Resources/Sounds/"; done
if [[ "${ONDE_ORIGINALS_ONLY:-0}" != "1" ]]; then
  for name in almost dreams; do f="Assets/$name.mp3"; [[ ! -f "$f" ]] || cp "$f" "$APP/Contents/Resources/Sounds/"; done
fi
for f in Assets/music-provenance.json Assets/incompetech-license-evidence.html; do [[ -f "$f" ]] && cp "$f" "$APP/Contents/Resources/"; done
ditto Assets/Orchestra "$APP/Contents/Resources/Orchestra"
cp LICENSE THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string></array>
<key>CFBundleIdentifier</key><string>app.onde.mac</string>
<key>CFBundleName</key><string>Onde</string>
<key>CFBundleDisplayName</key><string>Onde</string>
<key>CFBundleExecutable</key><string>Onde</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.6.0</string>
<key>CFBundleVersion</key><string>1.6.0</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHumanReadableCopyright</key><string>2026 Onde contributors. Code MIT; audio licensing in About &amp; Credits.</string>
</dict></plist>
PLIST
ONDE_PACKAGE_PATH="$APP" python3 - <<'STAMP'
import os, pathlib, plistlib, datetime, subprocess, re
p=pathlib.Path(os.environ['ONDE_PACKAGE_PATH'])/'Contents/Info.plist'
d=plistlib.loads(p.read_bytes())
v=pathlib.Path('VERSION').read_text().strip()
assert re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+',v)
build=os.environ.get('ONDE_BUILD') or datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d%H%M%S')
assert re.fullmatch(r'[0-9]{14}',build)
commit=os.environ.get('ONDE_COMMIT')
if not commit:
 r=subprocess.run(['git','rev-parse','HEAD'],capture_output=True,text=True)
 commit=r.stdout.strip() if r.returncode==0 else 'local'
d.update(CFBundleShortVersionString=v, CFBundleVersion=v, OndeBuild=build, OndeCommit=commit, OndeRepository='blancmathis/onde')
p.write_bytes(plistlib.dumps(d))
STAMP
if [[ ! -f Assets/AppIcon.icns ]]; then
  swift Tools/Icon.swift "$ROOT/Assets/icon1024.png"
  mkdir -p Assets/AppIcon.iconset
  for px in 16 32 128 256 512; do
    sips -z "$px" "$px" Assets/icon1024.png --out "Assets/AppIcon.iconset/icon_${px}x${px}.png" >/dev/null
    doubled=$((px * 2))
    sips -z "$doubled" "$doubled" Assets/icon1024.png --out "Assets/AppIcon.iconset/icon_${px}x${px}@2x.png" >/dev/null
  done
  iconutil -c icns Assets/AppIcon.iconset -o Assets/AppIcon.icns
fi
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP/Contents/MacOS/ondectl"
codesign --force --sign - "$APP/Contents/MacOS/Onde"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
printf '\nBuilt and ad-hoc signed: %s\n' "$APP"

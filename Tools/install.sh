#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -d dist/Onde.app ]] || { echo 'Run Tools/build.sh first.' >&2; exit 1; }
DEST="$HOME/Applications/Onde.app"
mkdir -p "$HOME/Applications" "$HOME/.local/bin"
if [[ -e "$DEST" ]]; then
  identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DEST/Contents/Info.plist" 2>/dev/null || true)
  [[ "$identifier" == "app.onde.mac" ]] || { echo 'Refusing to replace an unrelated app.' >&2; exit 1; }
  [[ ! -e "$HOME/Applications/Onde.previous.app" ]] || { echo 'An old backup already exists. Inspect it before reinstalling.' >&2; exit 1; }
  mv "$DEST" "$HOME/Applications/Onde.previous.app"
fi
if [[ -e "$HOME/.local/bin/onde" && ! -L "$HOME/.local/bin/onde" ]]; then
  echo 'Refusing to replace an existing non-symlink CLI.' >&2; exit 1
fi
ditto dist/Onde.app "$DEST"
ln -sfn "$DEST/Contents/MacOS/ondectl" "$HOME/.local/bin/onde"
printf 'Installed: %s\nCLI: %s\n' "$DEST" "$HOME/.local/bin/onde"
printf 'No shell configuration was changed. Add ~/.local/bin to PATH as needed.\n'

#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# swift test builds the native app, CLI, core and tests in one release build.
swift test -c release -j 2
exec bash Tools/package.sh

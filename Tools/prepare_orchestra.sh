#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 Tools/fetch_orchestra.py
mkdir -p .build/tools
swiftc -O Tools/PrepareOrchestra.swift -o .build/tools/prepare-orchestra
.build/tools/prepare-orchestra Resources/OrchestraSources.json .build/orchestra-raw Assets/Orchestra
cp Resources/VSCO2-CC0.txt Assets/Orchestra/LICENSE.txt

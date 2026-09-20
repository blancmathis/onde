#!/usr/bin/env python3
"""CI-only live SwiftUI/NSWindow motion checks. Temporary muted profile, no user data."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
output = root / 'QA/Espace/live-artwork'
output.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='onde-motion-', dir=os.environ.get('TMPDIR')) as folder:
    home = Path(folder)
    state = dict(version=1, mode='focus', layers={}, modeMixes={}, imported=[], mixes=[], history=[],
        preferences=dict(masterVolume=0, chimeVolume=0.25, fadeSeconds=2, startFadeSeconds=8,
            markers=[600,1200,1800], chimesEnabled=True, preventSleep=False, reducedMotion=False))
    (home/'state.json').write_text(json.dumps(state))
    env = dict(os.environ, ONDE_HOME=str(home), ONDE_MOTION_CHECK_DIR=str(home/'captures'))
    with (output/'motion-integration.log').open('w') as log:
        try:
            p = subprocess.run([str(root/'.build/release/Onde')], env=env,
                stdout=log, stderr=subprocess.STDOUT, timeout=150)
        finally:
            if (home/'captures').exists():
                shutil.copytree(home/'captures', output, dirs_exist_ok=True)
    if p.returncode:
        raise RuntimeError((output/'motion-integration.log').read_text())
    report = json.loads((output/'motion-integration.json').read_text())
    assert report['passed'] >= 35 and len(report['motifs']) == 12, report
    assert len(list((output/'live-frames').glob('*.png'))) == 48
    print(json.dumps({k:v for k,v in report.items() if k != 'recorded_frame_seconds'}, indent=2))

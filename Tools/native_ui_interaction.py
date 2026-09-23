#!/usr/bin/env python3
"""Run compile-time-only UI checks with a disposable profile; never use TCC bypasses."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
app = Path(sys.argv[1]).resolve()
output = root / 'QA/Espace/interaction'
output.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='oui-', dir=os.environ.get('TMPDIR')) as directory:
    home = Path(directory)
    state = dict(version=1, mode='focus', layers={}, modeMixes={}, imported=[], mixes=[], history=[],
                 preferences=dict(masterVolume=0, chimeVolume=0.25, fadeSeconds=0, startFadeSeconds=0,
                                  markers=[600, 1200, 1800], chimesEnabled=True, preventSleep=False, reducedMotion=True))
    (home / 'state.json').write_text(json.dumps(state))
    env = dict(os.environ, ONDE_HOME=str(home), ONDE_INTERACTION_OUTPUT=str(home / 'results'))
    with (output / 'application.log').open('w') as log:
        process = subprocess.Popen([str(app / 'Contents/MacOS/Onde')], env=env, stdout=log, stderr=log)
        try:
            code = process.wait(timeout=120)
        except subprocess.TimeoutExpired:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=3)
            code = 124
        finally:
            if (home / 'results').is_dir():
                shutil.copytree(home / 'results', output, dirs_exist_ok=True)
    print((output / 'application.log').read_text(errors='replace'), flush=True)
    if code:
        raise RuntimeError(f'Native UI fixture exited {code}')
    receipt = json.loads((output / 'interaction.json').read_text())
    print(json.dumps(receipt, indent=2), flush=True)
    assert receipt['ok'] and receipt['muted'] and receipt['passed'] > 20, receipt

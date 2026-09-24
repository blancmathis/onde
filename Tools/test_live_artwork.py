#!/usr/bin/env python3
"""Live native artwork checks on an ephemeral GitHub-hosted Mac, never a user's Mac.

The system motion preference is read, exercised in both states, and restored in a
finally block. Production SwiftUI accessibility values are not mocked or bypassed.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

if (os.environ.get('GITHUB_ACTIONS') != 'true' or
        os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted' or
        os.environ.get('RUNNER_OS') != 'macOS'):
    raise SystemExit('This accessibility fixture is restricted to disposable GitHub-hosted macOS runners.')

root = Path(__file__).resolve().parents[1]
output = root / 'QA/Espace/live-artwork'
output.mkdir(parents=True, exist_ok=True)
command = ['/usr/bin/defaults', 'read', 'com.apple.universalaccess', 'reduceMotion']
previous = subprocess.run(command, text=True, capture_output=True)
old = previous.stdout.strip() if previous.returncode == 0 else None
if old not in (None, '0', '1'):
    raise RuntimeError('Unexpected motion preference; nothing was changed: ' + str(old))

def set_motion(reduced):
    subprocess.run(['/usr/bin/defaults', 'write', 'com.apple.universalaccess',
        'reduceMotion', '-bool', 'true' if reduced else 'false'], check=True)

def run_case(reduced):
    destination = output / 'system-reduced' if reduced else output
    destination.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='onde-motion-', dir=os.environ.get('TMPDIR')) as folder:
        home = Path(folder)
        state = dict(version=1, mode='focus', layers={}, modeMixes={}, imported=[], mixes=[], history=[],
            preferences=dict(masterVolume=0, chimeVolume=0.25, fadeSeconds=2, startFadeSeconds=8,
                markers=[600,1200,1800], chimesEnabled=True, preventSleep=False, reducedMotion=False))
        (home/'state.json').write_text(json.dumps(state))
        env = dict(os.environ, ONDE_HOME=str(home), ONDE_MOTION_CHECK_DIR=str(home/'captures'),
            ONDE_MOTION_CASE='system-reduced' if reduced else 'animated')
        with (destination/'motion-integration.log').open('w') as log:
            try:
                p = subprocess.run([str(root/'.build/release/Onde')], env=env,
                    stdout=log, stderr=subprocess.STDOUT, timeout=150)
            finally:
                if (home/'captures').exists():
                    shutil.copytree(home/'captures', destination, dirs_exist_ok=True)
        if p.returncode:
            raise RuntimeError((destination/'motion-integration.log').read_text())
        report = json.loads((destination/'motion-integration.json').read_text())
        assert report['runner_system_reduce_motion'] == reduced, report
        if reduced:
            assert report['passed'] >= 5, report
        else:
            assert report['passed'] >= 35 and len(report['motifs']) == 25, report
            assert len(list((destination/'live-frames').glob('*.png'))) == 48
        print(json.dumps({k:v for k,v in report.items() if k != 'recorded_frame_seconds'}, indent=2))

try:
    for reduced in (False, True):
        set_motion(reduced)
        run_case(reduced)
finally:
    if old is None:
        subprocess.run(['/usr/bin/defaults', 'delete', 'com.apple.universalaccess', 'reduceMotion'], check=True)
    else:
        set_motion(old == '1')
    restored = subprocess.run(command, text=True, capture_output=True)
    actual = restored.stdout.strip() if restored.returncode == 0 else None
    receipt = dict(runner_environment=os.environ['RUNNER_ENVIRONMENT'],
        original_reduce_motion=old, restored_reduce_motion=actual, restored=actual == old)
    (output/'accessibility-fixture.json').write_text(json.dumps(receipt, indent=2))
    assert actual == old, receipt

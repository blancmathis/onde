#!/usr/bin/env python3
"""CI-only native captures; no install, publication, user profile or playback."""
import json, os, pathlib, shutil, subprocess, tempfile
root = pathlib.Path(__file__).resolve().parents[1]
output = root/'QA/Espace'
output.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='onde-espace-', dir=os.environ.get('TMPDIR')) as folder:
    home = pathlib.Path(folder)
    prefs = dict(masterVolume=0,chimeVolume=0.25,fadeSeconds=2,startFadeSeconds=8,markers=[600,1200,1800],chimesEnabled=True,preventSleep=False,reducedMotion=True)
    state = dict(version=1,mode='focus',layers={},modeMixes={},imported=[],mixes=[],history=[],preferences=prefs)
    (home/'state.json').write_text(json.dumps(state))
    env = dict(os.environ,ONDE_HOME=str(home),ONDE_DESIGN_SNAPSHOT_DIR=str(home/'captures'))
    with (output/'capture.log').open('w') as log:
        result = subprocess.run([str(root/'.build/release/Onde')],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=90)
    if (home/'captures').exists():
        for path in (home/'captures').iterdir():
            shutil.copy2(path,output/path.name)
    if result.returncode:
        raise RuntimeError(f'Capture exited {result.returncode}; inspect capture.log')
    receipt = json.loads((output/'capture.json').read_text())
    assert receipt['count']==17 and receipt['muted'] and not receipt['playing'], receipt
    assert receipt['timer_driver_checks']==3
    assert len(list(output.glob('*-native.png')))==17
    assert (output/'surface-0.png').read_bytes() != (output/'surface-8.png').read_bytes()
    print(json.dumps(receipt,indent=2))

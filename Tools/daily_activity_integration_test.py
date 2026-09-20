#!/usr/bin/env python3
"""Exercise real app timing, using isolated profiles with all sound layers disabled."""
import datetime as dt
import json, os, pathlib, shutil, subprocess, sys, tempfile, time
root = pathlib.Path(__file__).resolve().parents[1]
app = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else root/'dist/Onde.app').resolve()
cli = app/'Contents/MacOS/ondectl'
profile = pathlib.Path(tempfile.mkdtemp(prefix='onde-day-', dir='/tmp'))
env = dict(os.environ, ONDE_HOME=str(profile))
checks = []; process = None
log = (profile/'app.log').open('w')
def check(ok, label):
    if not ok: raise AssertionError(label)
    checks.append(label); print('PASS', label, flush=True)
def call(*args):
    p = subprocess.run([str(cli), *args], env=env, capture_output=True, text=True, timeout=45)
    if p.returncode: raise AssertionError((args,p.returncode,p.stdout,p.stderr))
    d = json.loads(p.stdout)
    if not d.get('ok'): raise AssertionError(d)
    return d['result']
def launch():
    global process
    process = subprocess.Popen([str(app/'Contents/MacOS/Onde')], env=env, stdout=log, stderr=log)
    deadline = time.monotonic()+35
    while time.monotonic() < deadline:
        if process.poll() is not None: raise AssertionError('App exited during launch')
        try: return call('status')
        except Exception: time.sleep(.2)
    raise AssertionError('App did not become ready')
def quit_app():
    call('quit'); process.wait(timeout=20)
def state(history):
    return dict(version=1, mode='focus', layers={}, modeMixes={}, imported=[], mixes=[], history=history,
        preferences=dict(masterVolume=0, chimeVolume=.25, fadeSeconds=0, markers=[600,1200,1800], chimesEnabled=True, preventSleep=False, reducedMotion=True))
try:
    # Reproduce a 26-hour legacy record twice. Today must include only its local-day overlap.
    now = dt.datetime.now().astimezone(); epoch = now.timestamp()
    midnight = now.replace(hour=0, minute=0, second=0, microsecond=0).timestamp()
    record = dict(id='legacy-26h', date=epoch-26*3600-978307200, mode='focus', seconds=26*3600)
    history = [record, dict(record,id='duplicate-26h')]
    (profile/'state.json').write_text(json.dumps(state(history)))
    s = launch(); expected = min(26*3600, epoch-midnight)
    check(abs(s['today_seconds']-expected)<.1, '26-hour duplicate records contribute only their unique local-day overlap')
    check(s['elapsed_seconds']==0 and s['status']=='stopped', 'Migration does not start playback or invent an active stopwatch')
    check(s['daily_history_estimated'] is True, 'Legacy estimate is explicitly identified')
    check(isinstance(s['today_time_zone'],str) and bool(s['today_time_zone']), 'Daily total reports its calendar time zone')
    quit_app()
    saved = json.loads((profile/'state.json').read_text())
    check(saved['history']==history, 'Historical records preserved verbatim')
    check(saved['activityLedger']['legacyRecordCount']==2, 'Migration persisted once')
    s = launch(); check(abs(s['today_seconds']-expected)<.1, 'Restart does not reimport or double count legacy history'); quit_app()
    # Independent new-day accounting profile, without historical estimates.
    (profile/'state.json').write_text(json.dumps(state([])))
    s = launch(); check(s['today_seconds']==0, 'Fresh ledger starts at zero')
    check(not s['daily_history_estimated'], 'New sessions do not claim estimated historical data')
    prefs = s['preferences']; call('meditate'); call('silence'); time.sleep(1.3); a = call('pause')
    check(a['today_seconds']>=1, 'Deliberate silent meditation records session time')
    check(abs(a['today_seconds']-a['elapsed_seconds'])<.15, 'Fresh session and daily time agree before midnight')
    time.sleep(1.2); b = call('status'); check(abs(b['today_seconds']-a['today_seconds'])<.02, 'Paused wall time is excluded')
    call('play'); time.sleep(1.1); before = call('status'); after = call('timer','reset')
    check(after['elapsed_seconds']<.25, 'Reset affects only the session stopwatch')
    check(after['today_seconds']>=before['today_seconds']-.02, 'Stopwatch reset does not erase daily activity')
    time.sleep(.5); c = call('stop'); d = call('stop')
    check(abs(d['today_seconds']-c['today_seconds'])<.02, 'Repeated stop does not double count activity')
    check(d['elapsed_seconds']==0, 'Stopped stopwatch resets while Today remains')
    check(d['preferences']==prefs, 'Daily accounting never changes volume or chime preferences')
    quit_app(); time.sleep(.6); e = launch()
    check(abs(e['today_seconds']-d['today_seconds'])<.1, 'Daily activity persists without counting time while the app is closed')
    check(e['status']=='stopped', 'Restart remains silent')
    check(e['active_sound_ids']==[], 'No test audio layers enabled')
    quit_app()
    print(json.dumps(dict(ok=True,passed=len(checks),output_muted=True,checks=checks),indent=2),flush=True)
finally:
    if process and process.poll() is None:
        process.terminate()
        try: process.wait(timeout=10)
        except subprocess.TimeoutExpired: process.kill()
    log.close()
    if sys.exc_info()[0] is None: shutil.rmtree(profile)
    else: print('Retained isolated test profile:',profile,file=sys.stderr)

#!/usr/bin/env python3
"""Saved-mix identity and deletion boundaries, using the actual native app.

Disposable muted profile only. This exercises the model command used by the
confirmation, not pointer interaction with the confirmation dialog itself.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

app = Path(sys.argv[1] if len(sys.argv) > 1 else 'dist/Onde.app').resolve()
cli = app / 'Contents/MacOS/ondectl'
profile = Path(tempfile.mkdtemp(prefix='onde-mix-delete-', dir='/tmp'))
env = dict(os.environ, ONDE_HOME=str(profile))
log = (profile / 'application.log').open('w')
process = None
checks = []

def call(*words, expected=0):
    reply = subprocess.run([str(cli), *words], env=env, capture_output=True, text=True, timeout=30)
    if reply.returncode != expected:
        raise AssertionError((words, reply.returncode, reply.stdout, reply.stderr))
    payload = json.loads(reply.stdout)
    assert payload.get('ok') == (expected == 0)
    return payload['result'] if expected == 0 else payload['error']

def check(condition, name):
    if not condition:
        raise AssertionError(name)
    checks.append(name)
    print('PASS', name, flush=True)

try:
    process = subprocess.Popen([str(app / 'Contents/MacOS/Onde')], env=env, stdout=log, stderr=log)
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        assert process.poll() is None, 'Fixture exited during startup'
        if (profile / 'control.sock').exists():
            state = call('status')
            break
        time.sleep(.1)
    else:
        raise AssertionError('Fixture did not start')
    check(state['status'] == 'stopped', 'No autoplay on launch')
    call('volume', '0')
    call('settings', 'fadeSeconds', '0')
    original = profile / 'original.m4a'
    shutil.copyfile(app / 'Contents/Resources/Sounds/chime.m4a', original)
    imported = call('import', str(original), '--title', 'Private fixture')
    call('solo', imported['id'])
    call('play')
    check(imported['id'] in call('status')['audio_playing_ids'], 'Imported fixture is playing, muted')
    call('mix', 'save', 'Same name')
    call('mix', 'save', 'Same name')
    mixes = call('mixes')
    check(len(mixes) == 2 and mixes[0]['id'] != mixes[1]['id'], 'Duplicate display names keep distinct IDs')
    deleted, kept = mixes[0]['id'], mixes[1]['id']
    before = call('status')
    check(call('mix', 'delete', 'Same name', expected=2)['code'] == 'ambiguous_mix', 'Ambiguous deletion is rejected')
    check(call('call', json.dumps({'command': 'mix.load', 'id': 'Same name', 'play': False}), expected=2)['code'] == 'ambiguous_mix', 'Ambiguous loading is rejected')
    check(call('mixes') == mixes, 'Ambiguous requests do not mutate saved mixes')
    unchanged = call('status')
    check(unchanged['layers'] == before['layers'] and unchanged['status'] == before['status'], 'Ambiguous loading does not change playback')
    # Put an ID-looking name first, with distinguishable layers, then resolve the real ID.
    call('call', json.dumps({'command': 'sound', 'id': imported['id'], 'volume': .12}))
    call('mix', 'save', deleted)
    shadow = call('mixes')[0]['id']
    loaded = call('call', json.dumps({'command': 'mix.load', 'id': deleted, 'play': False}))
    check(loaded['layers'] == mixes[0]['layers'], 'Loading by UUID takes priority over an earlier ID-looking name')
    call('play')
    before = call('status')
    history = call('history')
    call('mix', 'delete', deleted)
    remaining = call('mixes')
    check(len(remaining) == 2 and {m['id'] for m in remaining} == {kept, shadow}, 'Delete by UUID removes only the chosen saved mix, not a matching name')
    after = call('status')
    check(after['status'] == 'playing' and after['audio_playing_ids'] == before['audio_playing_ids'], 'Deleting a saved mix does not stop its active sound')
    check(after['elapsed_seconds'] >= before['elapsed_seconds'], 'Deleting a saved mix does not reset the session')
    check(after['layers'] == before['layers'] and after['preferences'] == before['preferences'], 'Levels, chimes and layers remain unchanged')
    check(original.exists() and (profile / 'Imports' / imported['filename']).exists(), 'Original and imported audio files remain intact')
    check(call('history') == history, 'Deleting a mix does not remove history')
    check(call('mix', 'delete', deleted, expected=2)['code'] == 'not_found', 'A stale confirmation never falls back to another mix name')
    check(call('call', json.dumps({'command': 'mix.load', 'id': deleted, 'play': False}), expected=2)['code'] == 'not_found', 'Stale loading is rejected even when a name matches')
    check(call('mixes') == remaining, 'Stale requests preserve both remaining mixes')
    call('pause')
    call('mix', 'delete', 'Same name')
    check([m['id'] for m in call('mixes')] == [shadow], 'Unique legacy-name deletion stays compatible')
    call('mix', 'delete', shadow.lower())
    check(call('mixes') == [] and call('status')['status'] != 'playing', 'Last mix deletion accepts a lowercase UUID without autoplay')
    call('quit')
    check(process.wait(timeout=8) == 0, 'Native termination remains clean')
    saved = json.loads((profile / 'state.json').read_text())
    check(saved['mixes'] == [] and len(saved['imported']) == 1, 'Deletion persists without removing imported audio')
    print(json.dumps({'ok': True, 'passed': len(checks), 'checks': checks}, indent=2), flush=True)
finally:
    if process is not None and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=3)
    log.close()
    if sys.exc_info()[0] is None:
        shutil.rmtree(profile)
    else:
        print('Retained failed test profile', profile, file=sys.stderr)

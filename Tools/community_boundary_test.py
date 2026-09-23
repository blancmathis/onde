#!/usr/bin/env python3
"""Fresh-install and malformed-control regression checks on a packaged app.

Only owned temporary profiles, silent recordings and muted output. Every
expected rejection is checked for state preservation, not merely a return code.
"""
from __future__ import annotations
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import wave

app = Path(sys.argv[1]).resolve()
cli = app / 'Contents/MacOS/ondectl'
profile = Path(tempfile.mkdtemp(prefix='ocb-', dir='/tmp'))
env = dict(os.environ, ONDE_HOME=str(profile))
process = None
secondary = None
checks = []
log = (profile / 'app.log').open('w')


def check(ok, name):
    if not ok:
        raise AssertionError(name)
    checks.append(name)
    print('PASS', name, flush=True)


def call(*args, expected=0):
    reply = subprocess.run([str(cli), *args], env=env, capture_output=True, text=True, timeout=30)
    assert reply.returncode == expected, (args, reply.returncode, reply.stdout, reply.stderr)
    body = json.loads(reply.stdout)
    assert body.get('ok') == (expected == 0), body
    return body['result'] if expected == 0 else body['error']


def start():
    global process
    process = subprocess.Popen([str(app / 'Contents/MacOS/Onde')], env=env, stdout=log, stderr=log)
    end = time.monotonic() + 45
    while time.monotonic() < end:
        assert process.poll() is None, 'Native app exited during first launch'
        reply = subprocess.run([str(cli), 'status'], env=env, capture_output=True, text=True, timeout=10)
        if reply.returncode == 0:
            return json.loads(reply.stdout)['result']
        assert reply.returncode == 3, (reply.stdout, reply.stderr)
        time.sleep(.1)
    raise AssertionError('First launch timed out')


def stable():
    state = call('status')
    return {key: state[key] for key in ['mode', 'status', 'preferences', 'layers', 'quiet_view', 'page']}


try:
    check(call('status', expected=3)['code'] == 'not_running', 'Absent app reports not-running without auto-launch')
    state = start()
    check(state['status'] == 'stopped' and state['elapsed_seconds'] == 0, 'Fresh first launch never autoplays or counts time')
    call('volume', '0')
    call('settings', 'preventSleep', 'false')
    call('settings', 'reducedMotion', 'true')
    call('mix', 'save', 'Existing fixture')
    baseline = stable()
    secondary = subprocess.Popen([str(app / 'Contents/MacOS/Onde')], env=env, stdout=log, stderr=log)
    check(secondary.wait(timeout=10) == 0 and process.poll() is None, 'A second instance exits without terminating the profile owner')
    check(stable() == baseline and len(call('mixes')) == 1, 'Second launch preserves the owned settings and library')
    invalid = [
        {'command': 'mode', 'mode': 'focus', 'play': 1},
        {'command': 'mode', 'mode': 'relax', 'play': 'false'},
        {'command': 'mode', 'mode': 'meditation', 'reset': 0},
        {'command': 'music.select', 'id': 'ambre', 'play': None},
        {'command': 'mix.load', 'id': 'Existing fixture', 'play': 0},
        {'command': 'generate.play', 'mode': 'relax', 'reset': 'true'},
        {'command': 'sound', 'id': 'rain', 'enabled': 1, 'volume': 0.27},
        {'command': 'settings', 'key': 'chimesEnabled', 'value': 0},
        {'command': 'settings', 'key': 'preventSleep', 'value': 1},
        {'command': 'settings', 'key': 'reducedMotion', 'value': 'false'},
        {'command': 'ui', 'page': 'settings', 'quiet': 1},
        {'command': 'ui', 'show': 0},
        {'command': 'ui', 'page': 42},
        {'command': 'timer.markers', 'seconds': [1, True, 3]},
    ]
    for request in invalid:
        before = stable()
        error = call('call', json.dumps(request), expected=2)
        check(error['code'] == 'invalid_argument' and stable() == before,
              'Reject malformed control without mutation: ' + json.dumps(request, sort_keys=True))
    # Wrong JSON shapes and broken clients must not poison the next valid request.
    for payload in [b'{broken}\n', b'[]\n', b'{"command":"unknown"}\n']:
        with socket.socket(socket.AF_UNIX) as connection:
            connection.settimeout(8)
            connection.connect(str(profile / 'control.sock'))
            connection.sendall(payload)
            reply = json.loads(connection.makefile('rb').readline())
            check(reply['ok'] is False, 'Malformed or unknown IPC request returns an error')
        check(call('status')['preferences']['masterVolume'] == 0, 'Valid commands work after a rejected IPC request')
    original = profile / 'silent.wav'
    with wave.open(str(original), 'wb') as audio:
        audio.setparams((1, 2, 8000, 16000, 'NONE', 'not compressed'))
        audio.writeframes(bytes(32000))
    imported = call('import', str(original), '--title', "Native 'private' fixture")
    copy = profile / 'Imports' / imported['filename']
    check(copy.exists() and copy.read_bytes() == original.read_bytes(), 'Import keeps an identical private copy')
    broken = profile / 'broken.wav'
    broken.write_text('not audio')
    before_ids = [item['id'] for item in call('sounds')]
    call('import', str(broken), expected=2)
    check([item['id'] for item in call('sounds')] == before_ids, 'An invalid recording cannot partially mutate the library')
    call('sound', 'remove', imported['id'])
    check(original.exists() and not copy.exists(), 'Removing an import preserves its original file')
    call('quit')
    check(process.wait(timeout=8) == 0, 'Fresh-profile audit exits through native termination')
    # Existing malformed bytes must be backed up, never silently overwritten.
    corrupt = b'{ deliberately malformed state\n'
    (profile / 'state.json').write_bytes(corrupt)
    recovered = start()
    backups = list(profile.glob('state-unreadable-*.json'))
    check(len(backups) == 1 and backups[0].read_bytes() == corrupt, 'Unreadable settings are backed up byte-for-byte')
    check(recovered['status'] == 'stopped' and recovered['last_error'], 'Recovery explains the problem and never autoplays')
    call('volume', '0')
    call('call', '{"command":"errors.clear"}')
    call('quit')
    check(process.wait(timeout=8) == 0, 'Acknowledged profile recovery can quit normally')
    print(json.dumps({'ok': True, 'passed': len(checks), 'checks': checks, 'muted_playback': True}, indent=2), flush=True)
finally:
    for child in [secondary, process]:
        if child is not None and child.poll() is None:
            child.terminate()
            try:
                child.wait(timeout=3)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait(timeout=3)
    log.close()
    print((profile / 'app.log').read_text(errors='replace'), flush=True)
    shutil.rmtree(profile)

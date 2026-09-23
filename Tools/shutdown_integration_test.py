#!/usr/bin/env python3
"""Exercise real native termination; a forced cleanup is always a test failure.

Only launches/kills children owned by this script, with disposable ONDE_HOME
profiles and master volume zero. Captures a macOS stack sample on any hang.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    parser.add_argument('--output', type=Path, default=Path('QA/FullAudit/shutdown'))
    args = parser.parse_args()
    app = args.app.resolve()
    binary = app / 'Contents/MacOS/Onde'
    cli = app / 'Contents/MacOS/ondectl'
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if not binary.is_file() or not cli.is_file():
        parser.error('Pass an existing packaged Onde.app')
    helper_source = output / 'request-termination.swift'
    helper_source.write_text('''import AppKit
import Foundation
// Send the same native quit request as the Dock, to our exact child PID only.
guard CommandLine.arguments.count == 3,
      let pid = Int32(CommandLine.arguments[1]),
      let app = NSRunningApplication(processIdentifier: pid),
      app.executableURL?.resolvingSymlinksInPath().path ==
        URL(fileURLWithPath: CommandLine.arguments[2]).resolvingSymlinksInPath().path
else { exit(2) }
exit(app.terminate() ? 0 : 3)
''')
    helper = output / 'request-termination'
    subprocess.run(['swiftc', str(helper_source), '-o', str(helper)], check=True, timeout=90)
    cases = ['idle', 'preview', 'finished-preview', 'repeated-preview',
             'recorded-preview', 'generated-preview', 'scheduled-chimes',
             'native-preview', 'native-generated-preview']
    results = []
    for case in cases:
        destination = output / case
        destination.mkdir(exist_ok=True)
        profile = Path(tempfile.mkdtemp(prefix='onde-shutdown-', dir='/tmp'))
        env = dict(os.environ, ONDE_HOME=str(profile))
        log = (destination / 'application.log').open('w')
        process = None
        result = {'case': case, 'ok': False}
        try:
            def call(*words: str, timeout: float = 15) -> dict:
                reply = subprocess.run([str(cli), *words], env=env,
                                       capture_output=True, text=True, timeout=timeout)
                if reply.returncode:
                    raise AssertionError(f'{words}: {reply.returncode}: {reply.stdout} {reply.stderr}')
                payload = json.loads(reply.stdout)
                if not payload.get('ok'):
                    raise AssertionError(payload)
                return payload['result']

            def wait_for(predicate, seconds: float = 30) -> dict:
                deadline = time.monotonic() + seconds
                last = None
                while time.monotonic() < deadline:
                    if process.poll() is not None:
                        raise AssertionError(f'App exited unexpectedly: {process.returncode}')
                    last = call('status')
                    if last.get('last_error'):
                        raise AssertionError(last['last_error'])
                    if predicate(last):
                        return last
                    time.sleep(.1)
                raise AssertionError(f'State not reached: {last}')

            def launch() -> dict:
                nonlocal process
                process = subprocess.Popen([str(binary)], env=env, stdout=log, stderr=log)
                deadline = time.monotonic() + 30
                while time.monotonic() < deadline:
                    if process.poll() is not None:
                        raise AssertionError(f'App exited on launch: {process.returncode}')
                    if (profile / 'control.sock').exists():
                        try:
                            return call('status')
                        except (AssertionError, subprocess.TimeoutExpired):
                            pass
                    time.sleep(.1)
                raise AssertionError('Startup timed out')

            state = launch()
            assert state['status'] == 'stopped', 'No autoplay on startup'
            call('volume', '0')
            call('settings', 'fadeSeconds', '0')
            call('timer', 'markers', '10,20,30')
            if 'recorded' in case:
                call('solo', 'rain')
                call('play')
                wait_for(lambda s: 'rain' in s['audio_playing_ids'])
            if 'generated' in case:
                call('focus')
                wait_for(lambda s: 'living' in s['audio_playing_ids'])
            if case == 'scheduled-chimes':
                call('meditate')
                call('silence')
                call('timer', 'reset')
                call('timer', 'markers', '1,2', '--seconds')
                wait_for(lambda s: s['elapsed_seconds'] > 2.5)
                events = call('events')
                assert len([e for e in events if e['type'] == 'chime']) == 2
            elif case != 'idle':
                for _ in range(5 if case == 'repeated-preview' else 1):
                    call('chime', 'preview')
                    time.sleep(.1)
                if case == 'finished-preview':
                    time.sleep(9)
            if case == 'preview':
                call('volume', '0')
                call('settings', 'chimeVolume', '0.63')
                time.sleep(.3)
                preview = call('status')
                assert preview['playback']['chime']['playing'], 'Unrelated stopped-state edits must not cut off a preview'
                assert preview['playback']['chime']['volume'] == 0, 'Master mute applies to a live preview'
                assert preview['elapsed_seconds'] == 0, 'A preview never starts the session clock'
            if case == 'finished-preview':
                assert not call('status')['playback']['chime']['retained'], 'Completed preview releases its player'
            # Persist a private mix and an immediate preference edit on quit.
            call('mix', 'save', 'Shutdown fixture')
            call('timer', 'markers', '10,20,30')
            state = call('status')
            assert state['preferences']['masterVolume'] == 0
            (destination / 'before-quit.json').write_text(json.dumps(state, indent=2))
            started = time.monotonic()
            if case.startswith('native-'):
                subprocess.run([str(helper), str(process.pid), str(binary)],
                               check=True, capture_output=True, text=True, timeout=8)
            else:
                call('quit', timeout=8)
            code = process.wait(timeout=8)
            result['quit_seconds'] = round(time.monotonic() - started, 3)
            assert code == 0, f'Abnormal native exit: {code}'
            saved = json.loads((profile / 'state.json').read_text())
            assert saved['preferences']['markers'] == [600, 1200, 1800]
            assert saved['preferences']['masterVolume'] == 0
            state = launch()
            assert state['status'] == 'stopped', 'Restart must not autoplay'
            assert state['preferences']['markers'] == [600, 1200, 1800]
            assert len(call('mixes')) == 1, 'Saved mix survives termination'
            call('quit', timeout=8)
            assert process.wait(timeout=8) == 0
            result['ok'] = True
        except Exception as error:
            result['error'] = f'{type(error).__name__}: {error}'
            if process is not None and process.poll() is None:
                try:
                    subprocess.run(['/usr/bin/sample', str(process.pid), '3', '1',
                                    '-file', str(destination / 'hang-sample.txt')],
                                   capture_output=True, text=True, timeout=8)
                except Exception as sample_error:
                    result['sample_error'] = str(sample_error)
        finally:
            # Never hide a failure by treating terminate/kill as a normal exit.
            if process is not None and process.poll() is None:
                result['forced_fixture_cleanup'] = True
                process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=3)
            log.close()
            state_file = profile / 'state.json'
            if state_file.is_file():
                shutil.copy2(state_file, destination / 'saved-state.json')
            shutil.rmtree(profile)
        results.append(result)
        print(json.dumps(result), flush=True)
    summary = {'ok': all(r['ok'] for r in results), 'cases': results,
               'passed': sum(r['ok'] for r in results), 'total': len(results)}
    (output / 'results.json').write_text(json.dumps(summary, indent=2))
    print(json.dumps(summary, indent=2), flush=True)
    return 0 if summary['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())

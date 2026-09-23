#!/usr/bin/env python3
"""Check a single immutable candidate on each hosted Mac; never publish it.

The child suites own their temporary, muted profiles. A timeout or forced
cleanup is a failed test, never a successful quit. All logs remain available.
"""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import time


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    app = args.app.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    root = Path(__file__).resolve().parents[1]
    suites = ['community_boundary_test.py', 'integration_test.py', 'shutdown_integration_test.py',
              'paused_selection_integration_test.py', 'mix_deletion_integration_test.py',
              'transition_integration_test.py', 'generative_integration_test.py',
              'gentle_start_integration_test.py', 'profile_integration_test.py',
              'relaxation_integration_test.py', 'listening_integration_test.py',
              'transport_integration_test.py', 'daily_activity_integration_test.py']
    results = []
    for filename in suites:
        print('RUN', filename, flush=True)
        path = output / (filename.removesuffix('.py') + '.log')
        command = ['python3', '-u', str(root / 'Tools' / filename), str(app)]
        if filename == 'shutdown_integration_test.py':
            command += ['--output', str(output / 'shutdown')]
        started = time.monotonic()
        with path.open('w') as log:
            process = subprocess.Popen(command, cwd=root, stdout=log,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            try:
                code = process.wait(timeout=480)
            except subprocess.TimeoutExpired:
                code = 124
                # Only this suite's owned process group, not any user's app.
                for signum in (signal.SIGTERM, signal.SIGKILL):
                    try:
                        os.killpg(process.pid, signum)
                    except ProcessLookupError:
                        break
                    try:
                        process.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        continue
                process.wait(timeout=5)
        result = {'suite': filename, 'exit_code': code,
                  'seconds': round(time.monotonic() - started, 3)}
        results.append(result)
        print(json.dumps(result), flush=True)
        print(path.read_text(errors='replace'), flush=True)
        (output / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    return 0 if all(item['exit_code'] == 0 for item in results) else 1


if __name__ == '__main__':
    raise SystemExit(main())

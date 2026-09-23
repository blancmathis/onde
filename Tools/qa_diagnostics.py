"""Capture only a fixture-owned process before failure cleanup; never mark recovery as success."""
from pathlib import Path
import json
import subprocess


def capture(process, home, label):
    if process is None or process.poll() is not None:
        return
    destination = Path(home) / (label + '-sample.txt')
    try:
        result = subprocess.run(['/usr/bin/sample', str(process.pid), '2', '1', '-file', str(destination)],
                                capture_output=True, text=True, timeout=20)
        print('FAILURE_SAMPLE', json.dumps({'pid': process.pid, 'label': label, 'exit': result.returncode}), flush=True)
        if destination.exists():
            print(destination.read_text(errors='replace'), flush=True)
        else:
            print(result.stdout, result.stderr, flush=True)
    except Exception as error:
        print('FAILURE_SAMPLE_UNAVAILABLE', str(error), flush=True)

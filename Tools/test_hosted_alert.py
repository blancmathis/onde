#!/usr/bin/env python3
"""Keep every framework variant's result and stack. Never changes the host's services."""
from pathlib import Path
import json
import subprocess
import time

output = Path('QA/AlertFramework')
output.mkdir(parents=True, exist_ok=True)
binary = output / 'alert-check'
subprocess.run(['swiftc', '-parse-as-library', 'Tools/HostedAlertSmoke.swift', '-o', str(binary)], check=True, timeout=90)
results = []
for mode in ['plain', 'application-icon', 'named-icon']:
    path = output / (mode + '.log')
    started = time.monotonic()
    with path.open('w') as log:
        process = subprocess.Popen([str(binary.resolve()), mode], stdout=log, stderr=log)
        try:
            code = process.wait(timeout=8)
        except subprocess.TimeoutExpired:
            code = 124
            try:
                subprocess.run(['/usr/bin/sample', str(process.pid), '2', '1', '-file', str(output / (mode + '-stack.txt'))], capture_output=True, timeout=20)
            except subprocess.TimeoutExpired:
                pass
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill(); process.wait(timeout=3)
    text = path.read_text(errors='replace')
    result = dict(mode=mode, exit_code=code, seconds=round(time.monotonic()-started, 3), passed=code==0 and 'FRAMEWORK_ALERT_OK' in text)
    results.append(result)
    print(json.dumps(result), flush=True); print(text, flush=True)
(output / 'results.json').write_text(json.dumps(results, indent=2))
# A failing stock-framework baseline remains a failed diagnostic, not a green app test.
raise SystemExit(0 if all(item['passed'] for item in results) else 1)

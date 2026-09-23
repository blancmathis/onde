#!/usr/bin/env python3
"""Require real, graceful exits after chimes in isolated, muted native profiles.

A timed-out process is sampled before test-only cleanup. Killing a fixture never
counts as a successful Quit. No existing application or user profile is touched.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", nargs="?", default="dist/Onde.app")
    parser.add_argument("--artifacts", default="QA/Audit/shutdown")
    args = parser.parse_args()
    app = Path(args.app).resolve()
    cli = app / "Contents/MacOS/ondectl"
    executable = app / "Contents/MacOS/Onde"
    if not cli.is_file() or not executable.is_file():
        parser.error("Pass an existing packaged Onde.app")
    artifacts = Path(args.artifacts).resolve()
    artifacts.mkdir(parents=True, exist_ok=True)
    results = []

    for scenario in ("idle", "preview-stopped", "preview-playing", "repeated-preview", "scheduled-chime"):
        profile = Path(tempfile.mkdtemp(prefix="onde-exit-", dir="/tmp"))
        env = dict(os.environ, ONDE_HOME=str(profile))
        process = None
        target = artifacts / scenario
        target.mkdir(exist_ok=True)
        log = (target / "application.log").open("w")
        started = time.monotonic()
        result = {"scenario": scenario, "ok": False}

        def call(*arguments):
            response = subprocess.run([str(cli), *arguments], env=env,
                                      capture_output=True, text=True, timeout=10)
            if response.returncode != 0:
                raise AssertionError((arguments, response.returncode, response.stdout, response.stderr))
            payload = json.loads(response.stdout)
            if payload.get("ok") is not True:
                raise AssertionError(payload)
            return payload["result"]

        def wait_status(predicate, description, timeout=30):
            deadline = time.monotonic() + timeout
            status = None
            while time.monotonic() < deadline:
                if process.poll() is not None:
                    raise AssertionError("App exited while waiting for " + description)
                status = call("status")
                if status.get("last_error"):
                    raise AssertionError(status["last_error"])
                if predicate(status):
                    return status
                time.sleep(0.1)
            raise AssertionError((description, status))

        def launch():
            nonlocal process
            process = subprocess.Popen([str(executable)], env=env, stdout=log, stderr=log)
            deadline = time.monotonic() + 20
            while time.monotonic() < deadline:
                if process.poll() is not None:
                    raise AssertionError("App exited before the control socket was ready")
                # Only not-running is transient. Do not swallow schema/runtime failures.
                response = subprocess.run([str(cli), "status"], env=env,
                                          capture_output=True, text=True, timeout=10)
                if response.returncode == 0:
                    payload = json.loads(response.stdout)
                    if payload.get("ok") is not True:
                        raise AssertionError(payload)
                    return payload["result"]
                if response.returncode != 3:
                    raise AssertionError((response.returncode, response.stdout, response.stderr))
                time.sleep(0.1)
            raise AssertionError("App did not become ready")

        def quit_normally():
            before = time.monotonic()
            call("quit")
            code = process.wait(timeout=10)
            if code != 0:
                raise AssertionError(f"Quit returned abnormal process exit {code}")
            return round(time.monotonic() - before, 3)

        try:
            initial = launch()
            assert initial["status"] == "stopped", initial
            call("volume", "0")
            call("settings", "fadeSeconds", "0")
            call("settings", "reducedMotion", "true")
            call("timer", "markers", "")
            call("mix", "save", "Shutdown preservation fixture")
            if scenario in ("preview-playing", "repeated-preview"):
                call("focus")
                wait_status(lambda s: s["timer_running"] and bool(s["audio_playing_ids"]), "audio readiness")
            if scenario.startswith("preview-"):
                call("chime", "preview")
            elif scenario == "repeated-preview":
                for _ in range(4):
                    call("chime", "preview")
                    time.sleep(0.05)
                call("pause")
            elif scenario == "scheduled-chime":
                call("timer", "markers", "1", "--seconds")
                call("meditate", "--reset")
                wait_status(lambda s: 1 in s["fired_markers"], "scheduled chime")
                events = call("events")
                assert any(e["type"] == "chime" and e.get("marker_seconds") == 1 for e in events), events
            status = call("status")
            assert status["last_error"] is None, status
            assert status["preferences"]["masterVolume"] == 0, status
            (target / "before-quit.json").write_text(json.dumps(status, indent=2))
            result["quit_seconds"] = quit_normally()
            disk = json.loads((profile / "state.json").read_text())
            assert disk["preferences"]["masterVolume"] == 0, disk
            assert disk["preferences"]["markers"] == status["preferences"]["markers"], disk
            assert any(m["name"] == "Shutdown preservation fixture" for m in disk["mixes"]), disk
            restarted = launch()
            assert restarted["status"] == "stopped" and not restarted["timer_running"], restarted
            assert restarted["preferences"] == status["preferences"], restarted
            assert any(m["name"] == "Shutdown preservation fixture" for m in call("mixes"))
            result["restart_quit_seconds"] = quit_normally()
            result["ok"] = True
        except Exception as error:
            result["error"] = repr(error)
            if process is not None and process.poll() is None:
                try:
                    sample = subprocess.run(["/usr/bin/sample", str(process.pid), "3", "-file", str(target / "hang-sample.txt")],
                                            capture_output=True, text=True, timeout=8)
                    (target / "sample-command.log").write_text(sample.stdout + sample.stderr)
                    sample_path = target / "hang-sample.txt"
                    if sample_path.is_file():
                        print(sample_path.read_text(errors="replace")[:24000], flush=True)
                except (OSError, subprocess.TimeoutExpired) as sampling_error:
                    result["sampling_error"] = repr(sampling_error)
            print("FAIL", scenario, repr(error), flush=True)
        finally:
            # Cleanup only this fixture's Popen child, and preserve failure in results.
            if process is not None and process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
            log.close()
            if (profile / "state.json").is_file():
                shutil.copyfile(profile / "state.json", target / "state.json")
            shutil.rmtree(profile)
        result["duration_seconds"] = round(time.monotonic() - started, 3)
        results.append(result)
        print(json.dumps(result, sort_keys=True), flush=True)
    report = {"ok": all(r["ok"] for r in results), "scenarios": results,
              "passed": sum(r["ok"] for r in results), "total": len(results)}
    (artifacts / "results.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2), flush=True)
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

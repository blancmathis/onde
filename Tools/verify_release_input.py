#!/usr/bin/env python3
"""Verify the identity of a tested release artifact without rebuilding it.

This does not replace native archive/security tests, code-signature checks or
platform validation. The publication job must also depend on all required gates.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import zipfile

ARCHIVE = 'Onde-macOS-universal.zip'
PLIST = 'Onde.app/Contents/Info.plist'


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def verify(directory: Path, commit: str, version: str) -> dict:
    require(re.fullmatch(r'[0-9a-f]{40}', commit) is not None, 'Expected an exact source commit')
    require(re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', version) is not None, 'Expected a release version')
    require((directory / 'checkout-sha.txt').read_text().strip() == commit, 'Candidate checkout differs from publication source')
    env_path = directory / 'release.env'
    require(env_path.stat().st_size < 1024, 'Release metadata is oversized')
    pairs = [line.split('=', 1) for line in env_path.read_text().splitlines()]
    require(all(len(pair) == 2 for pair in pairs), 'Malformed release metadata')
    env = dict(pairs)
    require(len(pairs) == len(env) == 3 and set(env) == {'TAG', 'VERSION', 'ONDE_BUILD'}, 'Unexpected or duplicate release metadata')
    build = env['ONDE_BUILD']
    require(re.fullmatch(r'[0-9]{14}', build) is not None, 'Invalid build identifier')
    require(env['VERSION'] == version and env['TAG'] == f'build-{build}-{commit[:8]}', 'Release tag or version differs from the tested build')
    path = directory / ARCHIVE
    require(0 < path.stat().st_size <= 350_000_000, 'Invalid archive size')
    checksum_path = directory / (ARCHIVE + '.sha256')
    require(checksum_path.stat().st_size < 256, 'Invalid checksum file size')
    checksum = checksum_path.read_text().strip()
    match = re.fullmatch(r'([0-9a-f]{64})  ' + re.escape(ARCHIVE), checksum)
    require(match is not None, 'Checksum does not identify the distribution archive')
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    require(digest.hexdigest() == match.group(1), 'Distribution bytes differ from the tested checksum')
    with zipfile.ZipFile(path) as archive:
        require(archive.namelist().count(PLIST) == 1, 'Expected one application metadata file')
        entry = archive.getinfo(PLIST)
        require(0 < entry.file_size < 65536, 'Invalid application metadata size')
        info = plistlib.loads(archive.read(entry))
        expected = dict(CFBundleIdentifier='app.onde.mac', CFBundleShortVersionString=version,
                        CFBundleVersion=version, OndeBuild=build, OndeCommit=commit,
                        OndeRepository='blancmathis/onde', LSMinimumSystemVersion='14.0')
        require(all(info.get(key) == value for key, value in expected.items()), 'Application identity differs from the tested release')
        for name in ['Onde', 'ondectl', 'onde-updater']:
            member = 'Onde.app/Contents/MacOS/' + name
            require(archive.namelist().count(member) == 1, 'Missing or duplicate bundled executable: ' + name)
            require(0 < archive.getinfo(member).file_size < 128_000_000, 'Invalid bundled executable size: ' + name)
    return dict(ok=True, commit=commit, version=version, build=build, archive=ARCHIVE,
                sha256=digest.hexdigest(), scope='Exact candidate identity; not a replacement for native gates')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('commit')
    parser.add_argument('version')
    args = parser.parse_args()
    print(json.dumps(verify(args.directory, args.commit, args.version), indent=2))

#!/usr/bin/env python3
"""Offline consistency checks; creates only disposable synthetic artifacts."""
import hashlib
from pathlib import Path
import plistlib
import tempfile
import unittest
import zipfile
from verify_release_input import ARCHIVE, PLIST, verify


class ReleaseInputTests(unittest.TestCase):
    commit = 'a' * 40
    version = '1.11.5'
    build = '20260923190000'

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='onde-release-input-')
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.info = dict(CFBundleIdentifier='app.onde.mac', CFBundleShortVersionString=self.version,
                         CFBundleVersion=self.version, OndeBuild=self.build, OndeCommit=self.commit,
                         OndeRepository='blancmathis/onde', LSMinimumSystemVersion='14.0')
        (self.folder/'checkout-sha.txt').write_text(self.commit+'\n')
        (self.folder/'release.env').write_text(f'TAG=build-{self.build}-{self.commit[:8]}\nVERSION={self.version}\nONDE_BUILD={self.build}\n')
        self.archive()

    def archive(self, missing=None):
        with zipfile.ZipFile(self.folder/ARCHIVE, 'w') as archive:
            archive.writestr(PLIST, plistlib.dumps(self.info))
            for name in ['Onde', 'ondectl', 'onde-updater']:
                if name != missing:
                    archive.writestr('Onde.app/Contents/MacOS/'+name, b'fixture-only')
        self.checksum()

    def checksum(self):
        digest=hashlib.sha256((self.folder/ARCHIVE).read_bytes()).hexdigest()
        (self.folder/(ARCHIVE+'.sha256')).write_text(digest+'  '+ARCHIVE+'\n')

    def verify(self):
        return verify(self.folder,self.commit,self.version)

    def test_consistent_candidate_is_accepted_without_modification(self):
        before={path.name:path.read_bytes() for path in self.folder.iterdir()}
        self.assertTrue(self.verify()['ok'])
        self.assertEqual(before,{path.name:path.read_bytes() for path in self.folder.iterdir()})

    def test_wrong_checkout_is_rejected(self):
        (self.folder/'checkout-sha.txt').write_text('b'*40)
        with self.assertRaisesRegex(ValueError,'checkout'):self.verify()

    def test_changed_bytes_are_rejected(self):
        with (self.folder/ARCHIVE).open('ab') as output:output.write(b'changed')
        with self.assertRaisesRegex(ValueError,'bytes'):self.verify()

    def test_checksum_for_another_filename_is_rejected(self):
        path=self.folder/(ARCHIVE+'.sha256')
        path.write_text(path.read_text().replace(ARCHIVE,'Other.zip'))
        with self.assertRaisesRegex(ValueError,'Checksum'):self.verify()

    def test_application_identity_fields_must_all_match(self):
        for key in self.info:
            with self.subTest(key=key):
                previous=self.info[key];self.info[key]='wrong';self.archive()
                with self.assertRaisesRegex(ValueError,'identity'):self.verify()
                self.info[key]=previous
        self.archive()

    def test_every_bundled_executable_is_required(self):
        for name in ['Onde','ondectl','onde-updater']:
            with self.subTest(name=name):
                self.archive(missing=name)
                with self.assertRaisesRegex(ValueError,'executable'):self.verify()

    def test_duplicate_metadata_is_rejected(self):
        import warnings
        with warnings.catch_warnings():
            warnings.simplefilter('ignore',UserWarning)
            with zipfile.ZipFile(self.folder/ARCHIVE,'a') as archive:archive.writestr(PLIST,plistlib.dumps(self.info))
        self.checksum()
        with self.assertRaisesRegex(ValueError,'one application'):self.verify()

    def test_release_environment_cannot_override_repeated_keys(self):
        with (self.folder/'release.env').open('a') as output:output.write('VERSION=9.9.9\n')
        with self.assertRaisesRegex(ValueError,'duplicate'):self.verify()

    def test_unrelated_tag_is_rejected(self):
        path=self.folder/'release.env';path.write_text(path.read_text().replace(self.commit[:8],'bbbbbbbb'))
        with self.assertRaisesRegex(ValueError,'tag'):self.verify()

    def test_invalid_arguments_are_rejected(self):
        for commit,version in [('main',self.version),(self.commit,'latest')]:
            with self.assertRaises(ValueError):verify(self.folder,commit,version)


if __name__ == '__main__':
    unittest.main(verbosity=2)

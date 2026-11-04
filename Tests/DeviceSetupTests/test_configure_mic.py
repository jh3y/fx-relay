"""Exercise installation/restore on a temporary fake volume, never the real mic."""
import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('configure_mic', ROOT / 'script/configure_mic.py')
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)


class DeviceSetupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='fxmic-install-test-')
        self.root = Path(self.temp.name)
        self.volume = self.root / 'fake-volume'
        self.volume.mkdir()
        self.backup = self.root / 'hardware-backups' / 'fixture'
        (self.backup / 'files').mkdir(parents=True)
        files = []
        for name, data in [('4_.wav', b'original user sample fixture'), ('readme.pdf', b'original manual fixture')]:
            (self.volume / name).write_bytes(data)
            (self.backup / 'files' / name).write_bytes(data)
            files.append({'path': name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
        (self.backup / 'manifest.json').write_text(json.dumps({'sourceVolume': str(self.volume.resolve()),
                                                              'configPresent': False, 'files': files}))
        self.root_patch = patch.object(setup, 'ROOT', self.root)
        self.mount_patch = patch.object(setup.os.path, 'ismount', return_value=True)
        self.root_patch.start()
        self.mount_patch.start()

    def tearDown(self):
        self.root_patch.stop()
        self.mount_patch.stop()
        self.temp.cleanup()

    def run_mode(self, mode):
        with contextlib.redirect_stdout(io.StringIO()):
            setup.operate(self.volume, self.backup, mode)

    def test_inspection_is_read_only(self):
        before = {p.name: p.read_bytes() for p in self.volume.iterdir()}
        self.run_mode('inspect')
        self.assertEqual(before, {p.name: p.read_bytes() for p in self.volume.iterdir()})
        self.assertFalse((self.backup / 'cue-pack-installation.json').exists())

    def test_install_and_restore_preserve_originals(self):
        before = {p.name: p.read_bytes() for p in self.volume.iterdir()}
        self.run_mode('install')
        self.assertEqual(set(p.name for p in self.volume.iterdir()), set(before) | setup.NAMES)
        self.run_mode('inspect')
        receipt = json.loads((self.backup / 'cue-pack-installation.json').read_text())
        self.assertEqual(receipt['status'], 'verified')
        self.assertEqual(set(receipt['completedFiles']), setup.NAMES)
        self.run_mode('restore')
        self.assertEqual(before, {p.name: p.read_bytes() for p in self.volume.iterdir()})

    def test_install_refuses_existing_sample(self):
        (self.volume / '1.wav').write_bytes(b'user-created sample')
        with self.assertRaisesRegex(ValueError, 'overwrite'):
            self.run_mode('install')
        self.assertEqual((self.volume / '1.wav').read_bytes(), b'user-created sample')
        self.assertFalse((self.volume / 'config.json').exists())

    def test_restore_refuses_user_modified_pack_file_before_deleting_anything(self):
        self.run_mode('install')
        (self.volume / '2.wav').write_bytes(b'new user content')
        before = {p.name: p.read_bytes() for p in self.volume.iterdir()}
        with self.assertRaisesRegex(ValueError, 'changed file'):
            self.run_mode('restore')
        self.assertEqual(before, {p.name: p.read_bytes() for p in self.volume.iterdir()})

    def test_backup_mismatch_prevents_writes(self):
        (self.volume / '4_.wav').write_bytes(b'changed original')
        with self.assertRaisesRegex(ValueError, 'Original file changed'):
            self.run_mode('install')
        self.assertFalse((self.volume / 'config.json').exists())
        self.assertFalse((self.volume / '1.wav').exists())

    def test_disconnect_before_first_write_stops_installation(self):
        with patch.object(setup.os.path, 'ismount', side_effect=[True, False]):
            with self.assertRaisesRegex(ValueError, 'disconnected'):
                self.run_mode('install')
        self.assertFalse((self.volume / '1.wav').exists())
        receipt = json.loads((self.backup / 'cue-pack-installation.json').read_text())
        self.assertEqual(receipt['status'], 'incomplete')


if __name__ == '__main__':
    unittest.main()

"""All writes use temporary fake volumes; no hardware or macOS settings involved."""
import contextlib
import io
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'script'))
import switch_bank_probe as bank


class BankProbeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.volume = self.root / 'FX MIC DISK'
        self.volume.mkdir()
        for name in ['1.wav', '2.wav', '3.wav', '4.wav', 'config.json']:
            shutil.copyfile(bank.BASE / name, self.volume / name)
        (self.volume / 'user-file.txt').write_text('Leave this intact')
        self.backups = self.root / 'backups'
        self.mount = patch.object(bank.os.path, 'ismount', return_value=True).start()
        patch.object(bank, 'BACKUPS', self.backups).start()
        self.addCleanup(patch.stopall)

    def run_mode(self, mode='inspect', backup=None):
        with contextlib.redirect_stdout(io.StringIO()):
            return bank.operate(self.volume, mode, backup)

    def contents(self):
        return {p.name: p.read_bytes() for p in self.volume.iterdir()}

    def test_inspection_has_no_writes(self):
        before = self.contents()
        self.run_mode()
        self.assertEqual(self.contents(), before)
        self.assertFalse(self.backups.exists())

    def test_apply_restore_round_trip_and_originals_untouched(self):
        before = self.contents()
        backup = self.run_mode('apply')
        self.assertEqual((self.volume / 'config.json').read_bytes(), (bank.PACK / 'config.json').read_bytes())
        self.assertEqual((backup / 'config-before.json').read_bytes(), before['config.json'])
        for name in before:
            if name != 'config.json': self.assertEqual((self.volume / name).read_bytes(), before[name])
        self.run_mode()
        self.run_mode('restore', backup)
        self.assertEqual(self.contents(), before)

    def test_unknown_config_or_changed_sample_refuses_before_backup(self):
        for name in ['config.json', '2.wav']:
            with self.subTest(name=name):
                original = (self.volume / name).read_bytes()
                (self.volume / name).write_bytes(b'User changes')
                before = self.contents()
                with self.assertRaises(ValueError): self.run_mode('apply')
                self.assertEqual(self.contents(), before)
                self.assertFalse(self.backups.exists())
                (self.volume / name).write_bytes(original)

    def test_staging_collision_is_not_overwritten(self):
        (self.volume / 'fxbridge-config.tmp').write_bytes(b'Unrelated existing file')
        before = self.contents()
        with self.assertRaises(FileExistsError): self.run_mode('apply')
        self.assertEqual(self.contents(), before)

    def test_restore_refuses_user_changes(self):
        backup = self.run_mode('apply')
        (self.volume / 'config.json').write_bytes(b'New user config')
        before = self.contents()
        with self.assertRaises(ValueError): self.run_mode('restore', backup)
        self.assertEqual(self.contents(), before)

    def test_restore_refuses_corrupt_backup(self):
        backup = self.run_mode('apply')
        (backup / 'config-before.json').write_bytes(b'Corrupt')
        before = self.contents()
        with self.assertRaises(ValueError): self.run_mode('restore', backup)
        self.assertEqual(self.contents(), before)

    def test_disconnect_before_replace_preserves_current_config(self):
        before = (self.volume / 'config.json').read_bytes()
        self.mount.side_effect = [True, True, True, False]
        with self.assertRaisesRegex(ValueError, 'disconnected'): self.run_mode('apply')
        self.assertEqual((self.volume / 'config.json').read_bytes(), before)
        self.assertEqual(next(self.backups.glob('*/config-before.json')).read_bytes(), before)

    def test_symlink_and_boot_volume_are_rejected(self):
        saved = self.root / 'config-original.json'
        (self.volume / 'config.json').rename(saved)
        (self.volume / 'config.json').symlink_to(saved)
        with self.assertRaises(ValueError): self.run_mode('apply')
        self.assertEqual(saved.read_bytes(), (bank.BASE / 'config.json').read_bytes())
        boot = self.root / 'FX MIC BOOT'; boot.mkdir()
        with self.assertRaises(ValueError): bank.operate(boot, 'apply')
        self.assertFalse(self.backups.exists())


if __name__ == '__main__':
    unittest.main()

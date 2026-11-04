"""Four-bank writes are tested only against disposable fake volumes."""
import contextlib
import io
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'script'))
import install_four_banks as four
import switch_bank_probe as writer

class FourBanksTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name); self.volume = self.root / 'FX MIC DISK'; self.volume.mkdir()
        for name in ['config.json', '1.wav', '2.wav', '3.wav', '4.wav']:
            shutil.copy2(four.BASE / name, self.volume / name)
        (self.volume / 'user-file.txt').write_text('keep me')
        self.backups = self.root / 'backups'
        patch.object(four, 'BACKUPS', self.backups).start()
        patch.object(writer.os.path, 'ismount', return_value=True).start()
        self.addCleanup(patch.stopall)
    def run_mode(self, mode='inspect', backup=None):
        with contextlib.redirect_stdout(io.StringIO()): return four.run(self.volume, mode, backup)
    def contents(self): return {p.name:p.read_bytes() for p in self.volume.iterdir()}
    def test_candidate_keeps_base_and_fx2_and_all_sample_bytes(self):
        base, candidate = four.verify_candidate()
        old = json.loads((four.BASE / 'config.json').read_text())
        new = json.loads((four.PACK / 'config.json').read_text())
        self.assertEqual(new['presets'][:2], old['presets'])
        self.assertEqual([p['pos'] for p in new['presets']], [0,1,2,3])
        for name in ['1.wav','2.wav','3.wav','4.wav']: self.assertEqual(base['deviceFiles'][name], candidate['deviceFiles'][name])
    def test_inspect_apply_restore_preserves_every_other_file(self):
        original = self.contents(); self.run_mode(); self.assertEqual(original,self.contents())
        backup = self.run_mode('apply')
        self.assertEqual((self.volume/'config.json').read_bytes(), (four.PACK/'config.json').read_bytes())
        for name,data in original.items():
            if name != 'config.json': self.assertEqual((self.volume/name).read_bytes(), data)
        self.run_mode('restore',backup); self.assertEqual(original,self.contents())
    def test_user_changes_and_double_apply_refused(self):
        self.run_mode('apply'); original = self.contents()
        with self.assertRaises(ValueError): self.run_mode('apply')
        self.assertEqual(original,self.contents())
        (self.volume/'2.wav').write_bytes(b'new user sample'); original = self.contents()
        with self.assertRaises(ValueError): self.run_mode()
        self.assertEqual(original,self.contents())
    def test_boot_volume_refused(self):
        boot = self.root/'FX MIC BOOT'; boot.mkdir()
        with self.assertRaises(ValueError): four.run(boot,'apply')
        self.assertFalse(self.backups.exists())

if __name__ == '__main__': unittest.main()

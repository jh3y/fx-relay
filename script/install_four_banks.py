#!/usr/bin/env python3
"""Guarded v2 → v3 config-only upgrade; inspect by default, preserve and verify rollback."""
import argparse
import json
from pathlib import Path
from switch_bank_probe import ROOT, PACK as BASE, digest, operate, verify_candidate as verify_two_banks

PACK = ROOT / 'hardware' / 'agent-cues-v3'
BACKUPS = ROOT / 'hardware-backups' / 'four-banks'


def verify_candidate():
    _, base = verify_two_banks()
    manifest = json.loads((PACK / 'manifest.json').read_text())
    if manifest['packVersion'] != 3 or set(manifest['deviceFiles']) != set(base['deviceFiles']):
        raise ValueError('Unexpected four-bank manifest.')
    for name, spec in manifest['deviceFiles'].items():
        file = PACK / name
        if file.is_symlink() or file.stat().st_size != spec['bytes'] or digest(file) != spec['sha256']:
            raise ValueError(f'Candidate checksum mismatch: {name}')
        if name != 'config.json' and spec != base['deviceFiles'][name]:
            raise ValueError('Four-bank upgrade must retain the original WAV bytes.')
    expected = json.loads((BASE / 'config.json').read_text())
    expected['name'] = 'FX-MIC BRIDGE CUES V3'
    for pos, pitch in [(2, -10.5), (3, 11.5)]:
        expected['presets'].append({'pos': pos, 'list': [
            {'effect': 'SAMPLE', 'speed': 1.0, 'pitch': pitch, 'level': 1.0}], 'trigger': {'row': 0}})
    if json.loads((PACK / 'config.json').read_text()) != expected:
        raise ValueError('Expected four fixed SAMPLE presets with the original first two intact.')
    if manifest['baseConfigSHA256'] != base['deviceFiles']['config.json']['sha256']:
        raise ValueError('Unexpected prior config identity.')
    return base, manifest


def run(volume, mode='inspect', backup=None):
    return operate(volume, mode, backup, candidate_pack=PACK, backup_root=BACKUPS, verifier=verify_candidate)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--volume', type=Path, required=True)
    parser.add_argument('--mode', choices=['inspect', 'apply', 'restore'], default='inspect')
    parser.add_argument('--backup', type=Path)
    args = parser.parse_args()
    try:
        run(args.volume, args.mode, args.backup)
    except (OSError, ValueError, KeyError) as error:
        parser.exit(1, f'Four-bank operation stopped: {error}\n')

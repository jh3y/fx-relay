#!/usr/bin/env python3
"""Inspect/apply/restore the v2 bank experiment. Replace only a verified config."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import uuid

from configure_mic import ROOT, PACK as BASE, digest, save_receipt, verify_pack

PACK = ROOT / 'hardware' / 'agent-cues-v2'
BACKUPS = ROOT / 'hardware-backups' / 'bank-probe'


def verify_candidate():
    base = verify_pack()
    manifest = json.loads((PACK / 'manifest.json').read_text())
    if manifest['packVersion'] != 2 or set(manifest['deviceFiles']) != set(base['deviceFiles']):
        raise ValueError('Unexpected v2 manifest.')
    for name, spec in manifest['deviceFiles'].items():
        file = PACK / name
        if file.is_symlink() or file.stat().st_size != spec['bytes'] or digest(file) != spec['sha256']:
            raise ValueError(f'Candidate checksum mismatch: {name}')
        if name != 'config.json' and spec != base['deviceFiles'][name]:
            raise ValueError('The experiment must retain all v1 sample bytes.')
    expected = json.loads((BASE / 'config.json').read_text())
    expected['name'] = 'FX-MIC BRIDGE CUES V2'
    expected['presets'].append({'pos': 1, 'list': [
        {'effect': 'SAMPLE', 'speed': 1.0, 'pitch': 10.5, 'level': 1.0}], 'trigger': {'row': 0}})
    if json.loads((PACK / 'config.json').read_text()) != expected:
        raise ValueError('Expected exactly two fixed SAMPLE presets, at 0 and +10.5 semitones.')
    if manifest['baseConfigSHA256'] != base['deviceFiles']['config.json']['sha256']:
        raise ValueError('Unexpected base config identity.')
    return base, manifest


def operate(volume, mode='inspect', backup=None, *, candidate_pack=None, backup_root=None, verifier=None):
    base, candidate = (verifier or verify_candidate)()
    pack = candidate_pack or PACK
    backups = backup_root or BACKUPS
    if volume.is_symlink():
        raise ValueError('Refusing a symlink for the microphone volume.')
    volume = volume.resolve(strict=True)
    if volume.name.upper().replace('-', ' ') != 'FX MIC DISK' or not os.path.ismount(volume):
        raise ValueError('Use the currently mounted normal FX MIC DISK, never FX MIC BOOT.')
    device = volume.stat().st_dev

    def check_mount():
        if not volume.is_dir() or not os.path.ismount(volume) or volume.stat().st_dev != device:
            raise ValueError('The microphone disconnected or its mount changed; stopping.')

    def verify_device(config_hash):
        check_mount()
        for name, spec in base['deviceFiles'].items():
            expected = config_hash if name == 'config.json' else spec['sha256']
            file = volume / name
            if file.is_symlink() or not file.is_file() or digest(file) != expected:
                raise ValueError(f'Device file differs from the expected pack: {name}')

    before = base['deviceFiles']['config.json']['sha256']
    after = candidate['deviceFiles']['config.json']['sha256']
    if mode == 'inspect':
        cfg = volume / 'config.json'
        if cfg.is_symlink(): raise ValueError('Refusing symlink config.')
        current = digest(cfg)
        if current not in (before, after): raise ValueError('Device has a different config; no files changed.')
        verify_device(current)
        version = base['packVersion'] if current == before else candidate['packVersion']
        print(f'Verified v{version} config and all four unchanged cues; inspection only.')
        return None

    if mode == 'apply':
        verify_device(before)
        target = (pack / 'config.json').read_bytes()
        stats = os.statvfs(volume)
        if stats.f_bavail * stats.f_frsize < max(8192, len(target) + stats.f_frsize):
            raise ValueError('Insufficient free space for a staged config replacement.')
        backups.mkdir(parents=True, exist_ok=True)
        backup = backups / (datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ-') + uuid.uuid4().hex[:8])
        backup.mkdir()
        original = (volume / 'config.json').read_bytes()
        if hashlib.sha256(original).hexdigest() != before: raise ValueError('Config changed during backup.')
        (backup / 'config-before.json').write_bytes(original)
        receipt = {'schemaVersion': 1, 'status': 'prepared', 'volume': str(volume),
                   'startedAtUTC': datetime.now(timezone.utc).isoformat(),
                   'beforeSHA256': before, 'afterSHA256': after,
                   'unchangedSamples': {k: v for k, v in base['deviceFiles'].items() if k != 'config.json'}}
        source_hash, target_hash = before, after
    elif mode == 'restore':
        if backup is None: raise ValueError('Restore requires the printed backup directory.')
        backup = backup.resolve(strict=True)
        if not backup.is_relative_to(backups.resolve()): raise ValueError('Backup must belong to this experiment.')
        receipt = json.loads((backup / 'receipt.json').read_text())
        if (receipt.get('status') == 'restored' or receipt.get('volume') != str(volume)
                or receipt.get('beforeSHA256') != before or receipt.get('afterSHA256') != after):
            raise ValueError('Backup receipt does not match this mounted device and experiment.')
        saved = backup / 'config-before.json'
        if saved.is_symlink(): raise ValueError('Refusing symlink backup.')
        target = saved.read_bytes()
        if hashlib.sha256(target).hexdigest() != before: raise ValueError('Original config backup checksum failed.')
        verify_device(after)
        source_hash, target_hash = after, before
    else:
        raise ValueError('Unknown mode.')

    receipt_path = backup / 'receipt.json'
    save_receipt(receipt_path, receipt)
    staging = volume / 'fxbridge-config.tmp'
    try:
        verify_device(source_hash)
        # Exclusive creation prevents overwriting any pre-existing file, including symlinks.
        with staging.open('xb') as stream:
            stream.write(target); stream.flush(); os.fsync(stream.fileno())
        if digest(staging) != target_hash: raise ValueError('Staged config read-back failed.')
        verify_device(source_hash)
        check_mount()
        os.replace(staging, volume / 'config.json')
        verify_device(target_hash)
        receipt['status'] = 'verified' if mode == 'apply' else 'restored'
        receipt['finishedAtUTC'] = datetime.now(timezone.utc).isoformat()
        save_receipt(receipt_path, receipt)
    except Exception as error:
        receipt['status'] = 'incomplete'
        receipt['error'] = str(error)
        save_receipt(receipt_path, receipt)
        raise
    print(f'{mode.capitalize()} verified; only config.json replaced. Backup: {backup}')
    print('Eject FX MIC DISK in Finder to restart/load the config. Keep bridge keyboard output OFF during tests.')
    return backup


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--volume', required=True, type=Path)
    parser.add_argument('--mode', choices=('inspect', 'apply', 'restore'), default='inspect')
    parser.add_argument('--backup', type=Path)
    args = parser.parse_args()
    try:
        operate(args.volume, args.mode, args.backup)
    except (OSError, ValueError, KeyError) as error:
        parser.exit(1, f'Bank experiment stopped: {error}\n')

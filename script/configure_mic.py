#!/usr/bin/env python3
"""Inspect, install, or restore the five-file cue pack using a verified local backup.

The default mode is read-only inspection. No formatting, firmware updates, or ejects.
Installation refuses existing target files. Restore removes only unchanged pack files.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import struct
import wave

ROOT = Path(__file__).resolve().parent.parent
PACK = ROOT / 'hardware' / 'agent-cues-v1'
NAMES = {f'{n}.wav' for n in range(1, 5)} | {'config.json'}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def relative_path(value):
    path = Path(value)
    if path.is_absolute() or not path.parts or '..' in path.parts:
        raise ValueError(f'Unsafe manifest path: {value}')
    return path


def verify_pack():
    manifest = json.loads((PACK / 'manifest.json').read_text())
    if set(manifest['deviceFiles']) != NAMES or manifest['packVersion'] != 1:
        raise ValueError('Unexpected pack manifest.')
    for name, spec in manifest['deviceFiles'].items():
        path = PACK / name
        if path.stat().st_size != spec['bytes'] or digest(path) != spec['sha256']:
            raise ValueError(f'Pack checksum mismatch: {name}')
    cfg = json.loads((PACK / 'config.json').read_text())
    if cfg['samples'] != [{'pos': n - 1, 'file': f'{n}.wav', 'playmode': 'oneshot'} for n in range(1, 5)]:
        raise ValueError('Unexpected sample routing.')
    if cfg['presets'] != [{'pos': 0, 'list': [{'effect': 'SAMPLE', 'speed': 1.0, 'pitch': 0.0, 'level': 1.0}], 'trigger': {'row': 0}}]:
        raise ValueError('Expected one fixed-pitch SAMPLE preset without modulation.')
    for slot, frequency in enumerate((1500, 2300, 3100, 3900), 1):
        with wave.open(str(PACK / f'{slot}.wav'), 'rb') as audio:
            if (audio.getnchannels(), audio.getsampwidth(), audio.getframerate(), audio.getnframes()) != (1, 2, 48000, 14400):
                raise ValueError(f'Unexpected WAV format: slot {slot}')
            values = struct.unpack('<14400h', audio.readframes(14400))
        if max(abs(v) for v in values) > 11469 or values[0] != 0 or values[-1] != 0:
            raise ValueError('Cue clipping/envelope check failed.')
        # Verify the steady portion contains the intended tone, independent of the generator.
        values = values[480:-480]
        real = sum(v * math.cos(2 * math.pi * frequency * i / 48000) for i, v in enumerate(values))
        imaginary = sum(v * math.sin(2 * math.pi * frequency * i / 48000) for i, v in enumerate(values))
        fraction = (real * real + imaginary * imaginary) / (sum(v * v for v in values) * len(values) / 2)
        if fraction < 0.99:
            raise ValueError(f'Expected frequency verification failed: {frequency} Hz')
    return manifest


def verify_originals(volume, backup, manifest):
    for spec in manifest['files']:
        rel = relative_path(spec['path'])
        if (volume / rel).is_symlink() or (backup / 'files' / rel).is_symlink():
            raise ValueError('Refusing symlink in backup/device files.')
        if digest(backup / 'files' / rel) != spec['sha256'] or digest(volume / rel) != spec['sha256']:
            raise ValueError(f'Original file changed or is missing: {rel}')


def save_receipt(path, receipt):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(receipt, indent=2) + '\n')
    temporary.replace(path)


def operate(volume, backup, mode):
    pack = verify_pack()
    backup = backup.resolve(strict=True)
    if not backup.is_relative_to((ROOT / 'hardware-backups').resolve()):
        raise ValueError('Backup must be inside this project’s hardware-backups directory.')
    original = json.loads((backup / 'manifest.json').read_text())
    volume = volume.resolve(strict=True)
    if volume != Path(original['sourceVolume']) or not os.path.ismount(volume):
        raise ValueError('Volume must match the backed-up, currently mounted FX MIC DISK.')
    if original['configPresent'] or any(Path(f['path']).name in NAMES for f in original['files']):
        raise ValueError('This installer only adds new files to the backed-up unconfigured device.')
    verify_originals(volume, backup, original)
    device_number = volume.stat().st_dev
    receipt_path = backup / 'cue-pack-installation.json'
    receipt = json.loads(receipt_path.read_text()) if receipt_path.exists() else None
    if receipt is not None and receipt.get('deviceFiles') != pack['deviceFiles']:
        raise ValueError('Installation receipt does not match this pack.')

    def check_mount():
        if not volume.is_dir() or not os.path.ismount(volume) or volume.stat().st_dev != device_number:
            raise ValueError('Mic was disconnected or its mount changed; stopping.')

    if mode == 'restore':
        if not receipt or receipt.get('status') == 'restored':
            raise ValueError('No active installation receipt to restore.')
        for name, spec in pack['deviceFiles'].items():
            path = volume / name
            if path.is_symlink() or (path.exists() and digest(path) != spec['sha256']):
                raise ValueError(f'Refusing to remove a changed file: {name}')
        # Remove the config first, then only the exact WAV files this pack installed.
        for name in ['config.json', '1.wav', '2.wav', '3.wav', '4.wav']:
            check_mount()
            path = volume / name
            if path.exists(): path.unlink()
        verify_originals(volume, backup, original)
        receipt['status'] = 'restored'
        receipt['restoredAtUTC'] = datetime.now(timezone.utc).isoformat()
        save_receipt(receipt_path, receipt)
        print('Original files verified; cue-pack files removed. Eject and restart the mic to apply.')
        return

    existing = [name for name in sorted(NAMES) if (volume / name).exists() or (volume / name).is_symlink()]
    if existing:
        if mode == 'inspect' and receipt and all((volume / name).is_file() and digest(volume / name) == spec['sha256'] for name, spec in pack['deviceFiles'].items()):
            print('Installed pack and original files verify successfully.')
            return
        raise ValueError('Refusing to overwrite existing device files: ' + ', '.join(existing))
    if receipt and receipt.get('status') != 'restored':
        raise ValueError('An earlier installation receipt needs review before reinstalling.')
    stats = os.statvfs(volume)
    free = stats.f_bavail * stats.f_frsize
    required = sum(math.ceil(spec['bytes'] / stats.f_frsize) * stats.f_frsize for spec in pack['deviceFiles'].values()) + 32768
    if free < required: raise ValueError(f'Not enough device space: {free} available, {required} required including reserve.')
    print(f'Backup verified: {backup}')
    print(f'Pack validated: four 300 ms mono PCM cues at 1500 / 2300 / 3100 / 3900 Hz.')
    print(f'Add only: {", ".join(sorted(NAMES))}. Existing device files stay byte-for-byte intact.')
    print(f'Free space {free:,} bytes; required with allocation/reserve {required:,} bytes.')
    if mode == 'inspect':
        print('Inspection only; no device files written.')
        return

    receipt = {'packVersion': 1, 'status': 'installing', 'volume': str(volume), 'completedFiles': [],
               'startedAtUTC': datetime.now(timezone.utc).isoformat(), 'deviceFiles': pack['deviceFiles']}
    save_receipt(receipt_path, receipt)
    try:
        # Config last: all referenced samples are present before it is added.
        for name in ['1.wav', '2.wav', '3.wav', '4.wav', 'config.json']:
            check_mount()
            with (volume / name).open('xb') as stream:
                stream.write((PACK / name).read_bytes())
                stream.flush()
                os.fsync(stream.fileno())
            if digest(volume / name) != pack['deviceFiles'][name]['sha256']:
                raise ValueError(f'Device read-back checksum failed: {name}')
            receipt['completedFiles'].append(name)
            save_receipt(receipt_path, receipt)
        verify_originals(volume, backup, original)
        receipt['status'] = 'verified'
        receipt['verifiedAtUTC'] = datetime.now(timezone.utc).isoformat()
        save_receipt(receipt_path, receipt)
        print('Installed and read-back verified all five files; originals unchanged.')
        print('Eject FX MIC DISK in Finder, then power-cycle the mic to load the pack.')
    except Exception as error:
        receipt['status'] = 'incomplete'
        receipt['error'] = str(error)
        save_receipt(receipt_path, receipt)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--volume', required=True, type=Path)
    parser.add_argument('--backup', required=True, type=Path)
    parser.add_argument('--mode', choices=('inspect', 'install', 'restore'), default='inspect')
    args = parser.parse_args()
    try:
        operate(args.volume, args.backup, args.mode)
    except (OSError, ValueError, KeyError, wave.Error) as error:
        parser.exit(1, f'Configuration stopped: {error}\n')


if __name__ == '__main__':
    main()

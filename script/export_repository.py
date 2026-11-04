#!/usr/bin/env python3
"""Create a curated standalone source directory. No git init, remote creation or upload."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parent.parent
FILES = ['Package.swift', 'README.md', 'CONTRIBUTING.md', 'THIRD_PARTY_NOTICES.md']
TREES = ['Sources', 'Tests', 'Resources', 'hardware', 'profiles', '.github', 'licenses']
DOCS = ['GETTING_STARTED.md', 'PROFILES.md', 'VOICE_OPTIONS.md', 'DEVELOPMENT.md', 'HISTORY.md', 'BRANDING.md', 'MANAGED_MACS.md']
SCRIPTS = ['build_and_run.sh', 'configure_mic.py', 'switch_bank_probe.py', 'install_four_banks.py',
           'generate_icon.swift', 'generate_brand.py', 'render_vectors.swift', 'render_ui.sh', 'render_ui.swift',
           'export_profiles.sh', 'export_profiles.swift', 'export_repository.py']

def export(destination):
    destination = destination.resolve()
    if destination.exists():
        raise ValueError('Destination already exists; choose a new directory. Nothing was replaced.')
    destination.mkdir(parents=True)
    def copy(source, target):
        if source.is_symlink(): raise ValueError(f'Refusing linked source: {source}')
        target.parent.mkdir(parents=True, exist_ok=True)
        if source.is_dir():
            for file in source.rglob('*'):
                if file.is_symlink(): raise ValueError(f'Refusing linked source: {file}')
            shutil.copytree(source, target, ignore=shutil.ignore_patterns('.DS_Store', '__pycache__'))
        else: shutil.copy2(source, target)
    for name in FILES + (['LICENSE'] if (ROOT/'LICENSE').is_file() else []): copy(ROOT/name, destination/name)
    for name in TREES: copy(ROOT/name, destination/name)
    for name in DOCS: copy(ROOT/'docs'/name, destination/'docs'/name)
    copy(ROOT/'docs/brand', destination/'docs/brand')
    for version in ['v0.4.0', 'v0.5.0']:
        copy(ROOT/'docs/previews'/version, destination/'docs/previews'/version)
    for name in SCRIPTS: copy(ROOT/'script'/name, destination/'script'/name)
    (destination/'.gitignore').write_text('.build/\n.swiftpm/\ndist/\n.DS_Store\n__pycache__/\n*.pyc\ndiagnostics/\nhardware-backups/\nversions/\n')
    manifest = {str(p.relative_to(destination)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in sorted(destination.rglob('*')) if p.is_file()}
    # Only generated/public-source content is allowlisted. No local configuration or reports.
    (destination/'SOURCE-MANIFEST.json').write_text(json.dumps({'sha256': manifest}, indent=2)+'\n')
    print(f'Prepared {len(manifest)} files at {destination}. No repository was published.')

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--destination', type=Path, required=True)
    args=parser.parse_args()
    try: export(args.destination)
    except (OSError, ValueError) as error: parser.exit(1, f'Export stopped: {error}\n')

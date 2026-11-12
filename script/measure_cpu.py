#!/usr/bin/env python3
"""Measure the existing FX Relay process; never launch capture or synthesize keys."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import plistlib
import subprocess
import time


def process_time(pid):
    result = subprocess.run(['/bin/ps', '-p', str(pid), '-o', 'time='],
                            capture_output=True, text=True, check=True, timeout=5)
    text = result.stdout.strip()
    days = 0
    if '-' in text:
        day_text, text = text.split('-', 1)
        days = int(day_text)
    seconds = 0.0
    for part in text.split(':'):
        seconds = seconds * 60 + float(part)
    return days * 86400 + seconds


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--state', choices=['monitor-open', 'windows-closed'], required=True,
                        help='Describe the UI state you have prepared; this script does not change windows.')
    parser.add_argument('--seconds', type=int, default=20)
    parser.add_argument('--expected-version')
    parser.add_argument('--sample', action='store_true', help='Also take a two-second process stack sample.')
    args = parser.parse_args()
    if not 4 <= args.seconds <= 60:
        parser.error('--seconds must be between 4 and 60')
    root = Path(__file__).resolve().parent.parent
    app = root / 'dist/FX Relay.app'
    with (app / 'Contents/Info.plist').open('rb') as stream:
        version = plistlib.load(stream)['CFBundleShortVersionString']
    if args.expected_version and args.expected_version != version:
        parser.error(f'Expected bundle {args.expected_version}, found {version}')
    processes = subprocess.run(['/bin/ps', '-axo', 'pid=,comm='], capture_output=True,
                               text=True, check=True, timeout=5)
    matches = []
    for line in processes.stdout.splitlines():
        fields = line.strip().split(None, 1)
        if len(fields) == 2 and fields[1] == str(app / 'Contents/MacOS/FXMicBridge'):
            matches.append(int(fields[0]))
    if len(matches) != 1:
        parser.error(f'Expected exactly one running app from dist, found {len(matches)}. Open it manually first.')
    pid = matches[0]
    print(f'Measuring one process: {pid}; bundle v{version}; {args.state}', flush=True)
    observations = []
    previous_cpu, previous_time = process_time(pid), time.monotonic()
    deadline = previous_time + args.seconds
    while time.monotonic() < deadline:
        time.sleep(min(2, max(0, deadline - time.monotonic())))
        current_cpu, current_time = process_time(pid), time.monotonic()
        interval, cpu = current_time - previous_time, current_cpu - previous_cpu
        observations.append({'interval_seconds': interval, 'cpu_seconds': cpu, 'cpu_percent': 100 * cpu / interval})
        print(f'{100 * cpu / interval:.2f}% CPU', flush=True)
        previous_cpu, previous_time = current_cpu, current_time
    mean = 100 * sum(x['cpu_seconds'] for x in observations) / sum(x['interval_seconds'] for x in observations)
    now = datetime.now(timezone.utc)
    folder = root / 'diagnostics' / (now.strftime('%Y-%m-%d') + '-performance')
    folder.mkdir(parents=True, exist_ok=True)
    stem = f'v{version}-{args.state}-{now.strftime("%H%M%S")}'
    report = {'at': now.isoformat(), 'bundle_version': version, 'pid': pid,
              'ui_state': args.state, 'ui_state_source': 'Caller-provided; visibility is not independently controlled by this script.',
              'method': 'Process CPU-time deltas; 100% equals one occupied core.',
              'mean_cpu_percent': mean, 'measurements': observations}
    destination = folder / (stem + '.json')
    destination.write_text(json.dumps(report, indent=2) + '\n')
    print(f'Mean: {mean:.3f}% CPU\nReport: {destination}', flush=True)
    if args.sample:
        profile = folder / (stem + '-sample.txt')
        result = subprocess.run(['/usr/bin/sample', str(pid), '2', '1', '-file', str(profile)],
                                capture_output=True, text=True, timeout=20)
        report['sample_exit_code'] = result.returncode
        report['sample_file'] = profile.name
        if result.returncode:
            report['sample_error'] = result.stderr.strip()
        destination.write_text(json.dumps(report, indent=2) + '\n')
        print(f'Sample exit: {result.returncode}; {profile}', flush=True)


if __name__ == '__main__':
    main()

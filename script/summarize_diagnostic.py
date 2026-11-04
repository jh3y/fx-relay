#!/usr/bin/env python3
"""Print a measurement summary from an FX-MIC diagnostic JSON report. No dependencies."""
import argparse
import json
import math
from pathlib import Path
import statistics


def number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def percentile(values, proportion):
    values = sorted(values)
    if not values:
        return '—'
    index = (len(values) - 1) * proportion
    left, right = math.floor(index), math.ceil(index)
    return f'{values[left] + (values[right] - values[left]) * (index - left):.1f}'


def summarize(report):
    if report.get('schemaVersion') != 1:
        raise ValueError('Unsupported diagnostic report schema; expected version 1.')
    metadata = report['metadata']
    lines = [f"FX Relay {metadata['appVersion']} · {metadata['inputName']}",
             f"Started: {report['startedAt']} · {report.get('endReason') or 'Checkpoint; session not finalized'}",
             f"Notes: {metadata.get('notes') or '(none)'}", '',
             '| Step | Result | Frames | RMS p10 / median / p90 dBFS | Max peak dBFS | Concentrated spectral peak Hz |',
             '| --- | --- | ---: | --- | ---: | --- |']
    outcomes = {result['stepID']: result['outcome'] for result in report.get('stepResults', [])}
    measurements = report.get('measurements', [])
    for step in report['protocolSteps']:
        rows = [row for row in measurements if row['stepID'] == step['id'] and row['phase'] == 'measuring']
        levels = [row['rmsDB'] for row in rows if number(row.get('rmsDB'))]
        peaks = [row['peakDB'] for row in rows if number(row.get('peakDB'))]
        tones = [row['dominantFrequencyHz'] for row in rows
                 if number(row.get('dominantFrequencyHz')) and row.get('peakConcentration', 0) >= 0.8
                 and number(row.get('rmsDB')) and number(row.get('thresholdDB'))
                 and row['rmsDB'] >= row['thresholdDB']
                 and number(row.get('spectrumAgeSeconds')) and 0 <= row['spectrumAgeSeconds'] <= 0.15]
        frame_label = 'frame' if len(tones) == 1 else 'frames'
        tone_text = f'{min(tones):.0f}–{max(tones):.0f} (median {statistics.median(tones):.0f}; {len(tones)} {frame_label})' if tones else '—'
        peak_text = f'{max(peaks):.1f}' if peaks else '—'
        level_text = ' / '.join(percentile(levels, p) for p in (0.1, 0.5, 0.9))
        lines.append(f"| {step['title']} | {outcomes.get(step['id'], 'not completed')} | {len(rows)} | {level_text} | {peak_text} | {tone_text} |")
    probe = report.get('hardwareProbe')
    if probe:
        lines.extend(['', 'Fine probe (every delivered buffer; windows up to 10 ms):',
                      f"Omitted windows: {probe.get('omittedWindows', 0)}; capacity: {probe.get('capacity', 'unknown')}",
                      '| Step | Windows | Audio covered (s) | Max channel RMS median / p90 dBFS | Max peak dBFS | Observation |',
                      '| --- | ---: | ---: | --- | ---: | --- |'])
        for step in report['protocolSteps']:
            rows = [row for row in probe.get('measurements', [])
                    if row.get('stepID') == step['id'] and row.get('phase') == 'measuring']
            levels, peaks, covered = [], [], 0.0
            for row in rows:
                channels = row.get('channels', [])
                rms = [c['rmsDB'] for c in channels if number(c.get('rmsDB'))]
                peak = [c['peakDB'] for c in channels if number(c.get('peakDB'))]
                if rms: levels.append(max(rms))
                if peak: peaks.append(max(peak))
                if number(row.get('sampleCount')) and number(row.get('sampleRate')) and row['sampleRate'] > 0:
                    covered += row['sampleCount'] / row['sampleRate']
            level_text = ' / '.join(percentile(levels, p) for p in (0.5, 0.9))
            peak_text = f'{max(peaks):.1f}' if peaks else '—'
            observation = str((report.get('stepObservations') or {}).get(step['id'], '—')).replace('|', '/').replace('\n', ' ')
            lines.append(f"| {step['title']} | {len(rows)} | {covered:.3f} | {level_text} | {peak_text} | {observation} |")
        lines.extend(['', 'Fine windows contain per-channel RMS, peak, signed mean and maximum adjacent-sample change; no audio.',
                      'Window timestamps estimate buffer end from callback arrival; jitter can overlap wall-clock intervals.',
                      'Compare repeated presses with both handling and quiet steps. A click alone does not identify a button.',
                      'Boundary windows and preparation/countdown are excluded from these tables but retained in the JSON.'])
    lines.extend(['', 'Only MEASURING intervals are summarized; preparation/countdown frames are excluded.',
                  'Spectral peaks require concentration ≥80%, RMS above the recorded threshold, and spectrum age ≤150 ms.',
                  'Peak frame counts can include cached FFT updates; they do not establish a stable tone or identify a button.',
                  'Meter measurements are sampled at up to 15 Hz; FFT updates at up to 10 Hz. These can miss brief transients; use the fine probe when present.',
                  'Send the original JSON report for the full timeline, per-channel levels, spectra, and events.'])
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path)
    args = parser.parse_args()
    try:
        if args.report.stat().st_size > 25 * 1024 * 1024:
            raise ValueError('Report exceeds the 25 MiB size limit.')
        print(summarize(json.loads(args.report.read_text())))
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.error(str(error))


if __name__ == '__main__':
    main()

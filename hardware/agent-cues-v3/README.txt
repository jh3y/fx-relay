FX-MIC Bridge — Agent Cues v3 (four-bank experiment)

Prepared locally. FX 3 and FX 4 frequencies are predicted, not physically validated.
The first two presets and all four WAVs are unchanged from v2. This config adds
SAMPLE pitch -10.5 at preset position 2 (FX 3) and +11.5 at position 3 (FX 4).
No-FX and FX 1 share base pitches; four banks provide 16 independent mappings.

Base/FX1: 1500, 2300, 3100, 3900 Hz (measured)
FX2:      2751, 4218, 5685, 7153 Hz (measured)
FX3:       818, 1254, 1690, 2126 Hz (predicted)
FX4:      2915, 4469, 6023, 7578 Hz (predicted)

Use script/install_four_banks.py from the project to inspect/apply/restore.
The installer accepts only the exact v2 config/cues, backs up config.json,
replaces only config.json and verifies read-back. It refuses user modifications.
Eject the normal FX MIC DISK in Finder to reload. Never use FX MIC BOOT.

In app v0.4.0, keep output OFF and check all four slots in each FX state with
trigger released. Recognition always runs; FX 3/4 actions start disabled.
After verifying the pitches/labels, enable actions for the desired banks before arming.
The bank names/positions must be confirmed by the observed signal. Orange does
not emit its own independently identifiable action. Previous packs stay intact.

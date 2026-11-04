FX-MIC Bridge — Agent Cues v2 (hardware experiment)

Status: prepared locally; not installed or physically validated.
The four WAV files are identical to v1. The only intended device change is
config.json: add a second SAMPLE preset at +10.5 semitones, retaining preset 0
at its original pitch. Both presets use fixed speed, level and no modulation.

Slot    Base Hz    Shifted Hz (predicted, not measurements)
1       1500       2751
2       2300       4218
3       3100       5685
4       3900       7153

This follows the reference configuration in tajchert/tink-agent. It does not
make orange automatically emit a sample or provide an independent HID event.
The experiment checks orange alone, then sample pitch after mode selection.
LED-to-preset mapping and mode cycle length must be observed on this unit.

Installation/rollback
Use script/switch_bank_probe.py (inspection is its default mode). It verifies
the exact installed v1 config and four cue WAVs, backs up config.json locally,
then replaces only that config and checks read-back. It refuses other configs.
Restore uses that saved receipt and only replaces an unchanged v2 config with
the verified original v1 bytes. Other device files are not removed or replaced.
Do not use the older configure_mic.py restore while v2 is installed.
Eject the normal FX MIC DISK in Finder after a verified change to reload it.
Never use FX MIC BOOT: this is a configuration experiment, not firmware.

Testing
Keep keyboard output OFF. App v0.2.5 detects only the four base cues; the shifted
cues can appear as PTT activity in preview. They must not dispatch real keys.
Keep the trigger RELEASED for mode selection AND sample playback.
Use the guided Orange FX button check to inspect isolated presses again.
Then inspect the same sample through a full FX-mode cycle, with spaced orange
and sample-play actions; record the LED labels and save the bridge check.
See docs/FX_BANK_CHECK.md for the exact sequence and interpretation.

App versions and device-pack versions are independent. Keep v1 unchanged.

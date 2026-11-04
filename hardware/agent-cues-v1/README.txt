FX-MIC Bridge — Agent Cues v1

Purpose
Four identifiable audio cues for sample-slot detection. These files contain
generated sine waves, not recorded speech. They do not enable automatic keyboard
actions in the current v0.1.2 instrumentation app.

Slot   File    Frequency   Duration
1      1.wav   1500 Hz     300 ms
2      2.wav   2300 Hz     300 ms
3      3.wav   3100 Hz     300 ms
4      4.wav   3900 Hz     300 ms

All files are 48 kHz, mono, signed 16-bit PCM, with a 0.35 peak amplitude and
10 ms fades. The single preset at position 0 plays samples at fixed pitch and
speed, without handle/shake/LFO modulation. This overrides the device's effect
configuration while installed. The original files remain on the device.

Before installation
Back up the device files. Use script/configure_mic.py with the backup directory;
its default mode only inspects. It validates the files and free space, verifies
the backup against the mounted device, and refuses to overwrite existing files.
Only 1.wav, 2.wav, 3.wav, 4.wav, and config.json are copied; this README and the
manifest stay on the Mac. Expected transfer size: 115,991 bytes.

After installation
1. Eject FX MIC DISK in Finder before disconnecting or restarting it.
2. If ejecting has not already restarted it, press the small power button above
   USB-C to turn it off, then squeeze the handle to turn it on again. The on-device
   guide says new sample/config files are loaded on restart.
3. Keep the analog audio connection to the USB adapter. USB-C provides file
   access/power; it does not replace the adapter's audio path.
4. Select preset position 0 (the reference pack uses no effect/preset LED for
   this position). Confirm the emitted frequency; factory effects or another
   preset can alter the sample.
5. Hold the handle. The sample SELECTOR cycles through four slots. The sample
   PLAY button emits the selected cue. Test one slot at a time in Signal Monitor:
   approximately 1500, 2300, 3100, then 3900 Hz. A short cue can disappear from
   the live readout quickly; a guided diagnostic report retains the measurements.

Button identification
The PDF on this unit labels orange as preset selection, green as sample
selection, and white as playback. The current web guide uses different colors.
Use the button's function/slot LEDs to identify it instead of relying on color.

Restore
script/configure_mic.py --volume '/Volumes/FX MIC DISK' --backup <backup-dir> --mode restore

Restore requires the installation receipt, verifies originals, and removes only
unchanged cue-pack files. It refuses files changed since installation so it
cannot delete later user content. Eject/restart afterward. If installation was
interrupted and a file is incomplete, inspect it before attempting recovery.

Design reference
https://github.com/tajchert/tink-agent/tree/main/ting-config
The tones are generated locally by script/prepare_cue_pack.py. The simple fixed
SAMPLE preset follows the device's own documented schema and the reference
project's fixed-pitch approach. Device behavior still requires a physical test.

# Voice in the shifted banks

On November 5, 2026, voice transcription was reported to stop with FX 3/4 selected and resume after returning to the base bank. This is a user-observed symptom, not yet a measured cause. The target application's state, exact playback sequence and the configuration currently loaded by the mic were not captured in that report.

The shipped v3 config contains four SAMPLE-only presets. They differ in sample pitch; there is no explicit HARMONY, RING, voice filter or mute effect in the file. That does not prove how the mic is processing live speech, or that the current device has loaded this file. The [manufacturer's guide](https://teenage.engineering/guides/ep-2350) describes effect chains and reloading the configuration after ejecting the disk. We should not infer a hardware fix from the JSON alone.

Use the base bank for voice until this check is complete. Continue treating FX 3/4 as experimental for simultaneous voice use.

## First: remove keyboard actions from the experiment

1. Choose **Quit** in FX Relay's menu bar. Closing its window is not enough. Keep the mic connected to the same audio adapter.
2. Start voice mode manually in the target app and confirm it is listening to that adapter. Do not press the mic's sample PLAY button during this check.
3. With the handle released, use orange to select the same base position that previously worked. Then squeeze the handle, say a short phrase, and release it.
4. With the handle still released, use orange to select FX 3. Then squeeze, say the same phrase, and release.
5. Repeat for FX 4, then return to the original base position and repeat once more. Confirm the target app remains in voice mode between attempts; note if it stops or mutes.

If the failure remains while FX Relay is quit, its synthesized keys cannot be causing that run. Next compare the selected input in an ordinary local audio recorder or input monitor to distinguish missing/altered microphone audio from a target-app recognition problem. A level meter alone cannot prove speech is intelligible. No audio needs to be uploaded, and FX Relay does not transcribe it.

If the failure disappears, reopen FX Relay with keyboard output disabled and repeat the same sequence. Then inspect the selected profile and event log before enabling any actions. An old Hold-Space profile, an Escape/Return mapping or a played command can affect a voice session even though the bridge does not modify its microphone stream.

## Then: verify the loaded hardware pack

Expose the normal **FX MIC DISK**, inspect its `config.json` and four cue-file hashes against the shipped v3 pack, and eject it to reload. Do not use firmware-update mode. Verify each bank's sample pitches separately with output off; do not mix the speech check with sample playback.

Record the app and version, input adapter, starting FX lights, whether PLAY was used, whether voice mode stayed active, and which steps worked. This distinguishes device configuration, audio quality, cue playback and keyboard output without guessing which caused the symptom.

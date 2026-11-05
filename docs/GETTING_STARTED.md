# From microphone to controller

Use the FX-MIC's analogue output through a Mac audio-input adapter. USB-C is for loading configuration and samples; the bridge observes the selected audio input during normal use. Select the same adapter independently in your terminal or dictation application. The bridge never changes the system input device.

## 1. Install the standard four-bank pack

In **Edit Mappings → Mic & Workflows**, choose the mounted normal **FX MIC DISK** drive. Inspection is read-only. The app shows exactly which files it will write. Click **Install Four Banks** to apply the inspected plan.

The installer supports an unconfigured device with no conflicting filenames, known Agent Cues v1/v2 upgrades, and verification of v3. It refuses unknown configurations, different samples, linked files, boot volumes and changes since inspection. Existing original files are preserved. Replaced files and a receipt are saved under `~/Library/Application Support/FX-MIC Bridge/Mic Backups/`.

Eject in Finder to reload, then resume monitoring. To undo a completed installation in the same app session, reconnect/reselect the drive and use **Restore Previous Setup**; the receipt and current device must still match. **Show Backup** exposes the files for later recovery. Failed/incomplete installations preserve their backup and report the error; they are not automatically treated as completed restores.

All four banks come with the pack. Fresh profiles enable all banks. Upgrades keep existing profile switches and mappings, so enable a previously disabled bank if you want its actions.

Use a firmware version that supports the documented JSON format. Development testing used firmware 1.1.2 after encountering the older JSON parsing issue; the app does not update firmware. Refer to the [manufacturer's EP-2350 guide](https://teenage.engineering/guides/ep-2350).

## 2. Check playback with output off

Release the handle for this check. In Signal Monitor, Reset Check. For each bank, select slots 1–4 and press PLAY once, waiting two seconds between plays. Confirm the corresponding counter increments once and the sample does not activate PTT. Save Bridge Check if anything differs.

| FX selection | Samples 1–4, Hz | Evidence |
| --- | --- | --- |
| No FX / FX 1 | 1500 / 2300 / 3100 / 3900 | Measured |
| FX 2 | 2751 / 4218 / 5685 / 7153 | Measured |
| FX 3 | 818 / 1254 / 1690 / 2126 | Predicted; physical check pending |
| FX 4 | 2915 / 4469 / 6023 / 7578 | Predicted; physical check pending |

Change FX while the handle is released. The orange and sample-selector buttons do not have independently measured audio events. Only playback identifies the bank and slot. With an older pack, some FX states may play identical base sounds and consequently map to base actions.

## 3. Test keys, then your workflow

Choose a starter profile and review its setup notes. To test without submitting a command, map a sample to Type Text `hello` with Enter off. Apply Changes, click **Enable Output in 3 Seconds**, and focus a blank TextEdit document during the countdown. A single sample should insert one `hello`.

Output is tied to the focused target process; switching apps disarms it. Returning to mappings also disables output. Never use an untested mapping in an important document. System shortcuts are explicitly marked in their action editor and still require arming/focus/permissions.

Microphone permission allows observation; Accessibility permission permits synthesized keys. Each has an explanation and System Settings button in the app. No recording permission is requested by this setup for a remote service.

[Starter profiles](PROFILES.md) explain Codex, Claude and Apple Dictation. Their recognition stays in the target service. The bridge only sends controls.

## 4. Check handle detection separately

1. Open Signal Monitor with keyboard output off. Choose the desired **Handle bank** manually, or identify it by playing a sample.
2. Wait quietly, then squeeze and **speak for a few seconds**. Confirm the input meter rises and **Sound detector: ACTIVE** appears. A silent squeeze is not a reliable test; the mic has no digital handle-switch event.
3. Stop speaking and release. The detector should return to idle after the configured release delay, initially 900 ms. Use **Edit Mappings → Detection** for PTT activation/confirmation/release settings; the monitor's signal threshold only controls signal start/end logging.
4. Review the bank's **Handle** mapping. For a keyboard check, use Hold Space and arm output into a disposable TextEdit document during the countdown. Speaking should post a Space down, followed by an up after silence. The event log records dispatch; the separate **Manual test DOWN/UP** counters are only for the manual TEST SPACE button.
5. Switching focus back to the bridge disarms output. Use **Save Bridge Check** to export detector traces, bank identity, mapping and event logs if the result differs.

Receiving a Space event does not establish voice compatibility in a terminal. Claude's terminal hold mode uses key repeats, while generic Hold Key sends one down/up pair. For `/voice hold`, select **Hold Key — Continuous** in the bank's Handle action. The Claude Code · Tap starter is the separate toggle workflow. Sound-based activation can miss the beginning of speech and release during pauses; it does not establish true physical push-to-talk.

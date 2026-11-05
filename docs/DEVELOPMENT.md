# Development

macOS 15 or later. Swift Package Manager; no external dependencies. The app is menu-bar-only and deliberately has no Dock icon. Use full Xcode for XCTest. If your selected toolchain is Command Line Tools, run tests with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

```sh
./script/build_and_run.sh --build-only
swift test --jobs 2 --configuration release
python3 -m unittest discover -s Tests/DeviceSetupTests -v
```

The build creates a proper `.app` bundle, includes AppIcon.icns and all cue-pack versions needed for validation/upgrades, ad-hoc signs it with audio-input entitlement, and verifies the signature. It gracefully stops an existing copy before replacing the bundle. At most two compiler jobs run by default. `--debug` uses an unoptimized build; normal use is optimized. `FXMIC_SIGNING_IDENTITY` can supply a development identity.

## Architecture

| Component | Responsibility |
| --- | --- |
| AudioDeviceManager / AudioCaptureEngine | Enumerate inputs and capture the chosen device without changing system audio |
| SignalAnalyzer / AudioSampleProcessor | PCM, RMS/peak, waveform and spectrum off the main thread |
| ControlAnalyzer / PTTDetector / ToneDetector | Fixed analysis blocks, sound gating and conservative cue recognition |
| BankHandleRouter | Last-cue/manual bank identity, per-bank handle routing, quiet-before-rearm and release decisions |
| ActionDispatcher / HeldKeyLease / TextActionRunner | Focused output, balanced events, timeout release and cancellable typing |
| ProfileStore / ProfileManager | Validated local JSON, starters, migration and editable mappings |
| CuePackInstaller / MicSetupModel | Native inspection, backup, install and restore of the standard pack |
| LiveReadings | Throttled UI snapshots only for visible windows/popovers |

FFT refresh is capped at 10 Hz, visible readings at 15 Hz, and diagnostic measurements at 5 Hz. Controls run at 25 Hz independently of visibility. Tone probes are cached and skipped below the level floor. No speech model, networking client or shell action is included.

## Visual assets and checks

```sh
xcrun swift script/generate_icon.swift
iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
python3 script/generate_brand.py
./script/render_ui.sh
```

The render helper compiles the actual SwiftUI screens with optimized core artifacts and an isolated preference suite. It never starts audio or posts keys. Its light/dark PNGs and width/height assertions are layout checks; they do not replace live interaction checks. The helper currently targets Apple Silicon. Build the core with the full Xcode toolchain before using it.

## Releases

The local build is not a notarized public distribution. Shipping a trusted download requires the maintainer's Developer ID, signing and notarization credentials. Those are not stored here. The GitHub workflow builds/tests an ad-hoc development artifact; no publication or notarization is automated.

Historical development snapshots remain in the originating workspace. [Progress](HISTORY.md) records milestones. The originating workspace’s snapshot tool preserves source, app ZIP and hashes without replacing old snapshots. Public exports omit local snapshots, diagnostic reports and device backups. `script/export_repository.py` creates a new curated directory and manifest; it refuses to overwrite an existing directory and does not create/push a remote.

The product name became **FX Relay** in v0.5.0. The executable/module (`FXMicBridge`), bundle identifier (`com.jhey.fxmicbridge`), preference keys and existing backup directory keep their original names so saved settings and earlier snapshots continue to work. The built application is `dist/FX Relay.app`.

Profile JSON schema 3 stores four handle actions. Legacy handle settings are retained for decoding and migrate to the same effective action in each bank. ProfileStore writes a new v4 preference key without changing older library bytes. PTTDetector always observes sound; BankHandleRouter and ActionDispatcher separately decide mapping and keyboard output. Bridge Check schema 4 includes handle bank, identification source and routing state.

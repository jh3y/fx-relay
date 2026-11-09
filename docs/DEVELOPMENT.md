# Development

macOS 15 or later. Swift Package Manager; no external dependencies. The app is menu-bar-only and deliberately has no Dock icon. Use full Xcode for XCTest. If your selected toolchain is Command Line Tools, run tests with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

```sh
./script/build_and_run.sh --build-only
swift test --jobs 2 --configuration release
python3 -m unittest discover -s Tests/DeviceSetupTests -v
```

The build creates a proper `.app` bundle, includes AppIcon.icns and all cue-pack versions needed for validation/upgrades, signs it with the audio-input entitlement, and verifies the signature. It gracefully stops an existing copy before replacing the bundle. At most two compiler jobs run by default. `--debug` uses an unoptimized build; normal use is optimized. Configure a stable identity with the [signing setup](SIGNING.md); otherwise the build uses ad-hoc signing.

## Architecture

| Component | Responsibility |
| --- | --- |
| AudioDeviceManager / AudioCaptureEngine | Enumerate inputs and capture the chosen device without changing system audio |
| SignalAnalyzer / AudioSampleProcessor | PCM, RMS/peak, waveform and spectrum off the main thread |
| ControlAnalyzer / PTTDetector / ToneDetector | Fixed analysis blocks, sound gating and conservative cue recognition |
| BankHandleRouter | Explicit startup/last-cue/manual bank identity, per-bank handle routing, quiet-before-rearm and release decisions |
| ForegroundOutputGate / ActionDispatcher / HeldKeyLease / TextActionRunner | Focused output, balanced events, timeout release and cancellable typing |
| ProfileStore / ProfileManager | Validated local JSON, starters, migration and editable mappings |
| CuePackInstaller / MicSetupModel | Native inspection, backup, install and restore of the standard pack |
| LiveReadings | Throttled UI snapshots only for visible windows/popovers |
| BridgeReadiness / UtilityPreferences | Permission/capture readiness, first-run migration and reference-window preference |
| LoginItemManager | Explicit main-app login registration through ServiceManagement; actual OS status is the source of truth |

FFT refresh is capped at 10 Hz, visible readings at 15 Hz, and diagnostic measurements at 5 Hz. Controls run at 25 Hz independently of visibility. Tone probes are cached and skipped below the level floor. No speech model, networking client or shell action is included.

## Visual assets and checks

```sh
xcrun swift script/generate_icon.swift
iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
python3 script/generate_brand.py
./script/render_ui.sh docs/previews/v0.7.0
```

The render helper compiles the actual SwiftUI screens with optimized core artifacts and an isolated preference suite. It never starts audio or posts keys. Its light/dark PNGs and width/height assertions are layout checks; they do not replace live interaction checks. The helper currently targets Apple Silicon. Build the core with the full Xcode toolchain before using it.

## Releases

The local build is not a notarized public distribution. Shipping a trusted download requires the maintainer's Developer ID, signing and notarization credentials. Those are not stored here. The GitHub workflow builds/tests an ad-hoc development artifact; no publication or notarization is automated.

Historical development snapshots remain in the originating workspace. [Progress](HISTORY.md) records milestones. The originating workspace’s snapshot tool preserves source, app ZIP and hashes without replacing old snapshots. Public exports omit local snapshots, diagnostic reports and device backups. `script/export_repository.py` creates a new curated directory and manifest; it refuses to overwrite an existing directory and does not create/push a remote.

The product name became **FX Relay** in v0.5.0. The executable/module (`FXMicBridge`), bundle identifier (`com.jhey.fxmicbridge`), preference keys and existing backup directory keep their original names so saved settings and earlier snapshots continue to work. The built application is `dist/FX Relay.app`.

Profile JSON schema 4 adds an explicit continuous-hold action to the four per-bank handle mappings. Legacy handle settings are retained for decoding and migrate to the same effective action in each bank. ProfileStore writes a new v5 preference key without changing older library bytes. PTTDetector always observes sound; BankHandleRouter and ActionDispatcher separately decide mapping and keyboard output. Bridge Check schema 4 includes handle bank, identification source and routing state.

v0.7.1 exports profile schema 5 and saves library v6, preserving the earlier keys. Hold Key can explicitly use system delivery. Standalone modifiers use `flagsChanged` events, including side-specific flags, rather than ordinary repeating key-downs. Existing leases and focus/capture guards own release, and modifier holds cannot overlap another bridge key action.

The queried global modifier state can include our own synthetic press. Since v0.7.2, release explicitly removes the modifier side FX Relay owns, preserving unrelated modifiers and the opposite side when its flag is present. A modifier already active before acquisition is not acquired. The state query cannot distinguish a physical press of that same side during a synthetic hold.

Continuous holds use repeated Quartz keyDown events. Process-targeted delivery leaves the autorepeat flag unset: in a real iTerm2 PTY test, marked targeted repeats produced only the initial Space, while unmarked targeted repeats delivered all 41 presses. The macOS system-event path retains the native autorepeat flag. ActionDispatcher requests repeats only after focus/permission/fresh-frame checks; HeldKeyLease serializes them with release, limits their cadence and never generates repeats independently. Normal Hold Key is unchanged. QuartzChordSink supports an injected event receiver for validating native event fields without sending keys.

Automatic output has no arming countdown. ForegroundOutputGate rejects queued pre-focus and stale frames, requires quiet after each target change, and requests release before a new target is accepted. App-level tests inject focus, permission and key sinks to verify automatic resume, balanced holds and continuous repeats without posting real keys. Microphone, permission, editing, diagnostic and pause states suspend output centrally. Explicit Pause is stored separately from profiles. Closing the monitor or applying mappings does not require re-enabling output.

## Native terminal receipt check

With iTerm2 installed, run `./script/check_terminal_output.sh`. This stops the development bridge, builds it, and opens a uniquely named receiver window. Leave that window focused for about five seconds. It counts Space bytes without saving other typed text, compares legacy marked repeats with current process-targeted repeats, saves private reports under `diagnostics/`, and reopens the bridge normally. It does not use your agent session or capture audio. Focus/permission loss stops the check, and the held-key lease releases independently.

## Native modifier release check

Quit the bridge, then run `open -n "dist/FX Relay.app" --args --modifier-release-check /tmp/fx-relay-modifier-check.json`. Release keyboard modifiers and leave its temporary window focused. The check briefly presses Shift, reproduces the old release with immediate cleanup, then verifies normal release, lease expiry and a subsequent hold at both the annotated session event tap and AppKit receiver. It records only its own tagged Shift events, captures no audio, closes itself and quits. Reopen FX Relay normally afterward. This checks native event delivery; dictation insertion remains a separate target-app test.

Development builds without a configured certificate use ad-hoc signatures. Rebuilding those may require Accessibility approval again (toggle FX Relay off/on in System Settings) and microphone access to be renewed from the app. Use [local development signing](SIGNING.md) to keep subsequent builds certificate-bound. Confirm capture has actually started before evaluating hardware: v0.7’s Ready status requires both permissions and incoming audio buffers. It does not claim a physical control was verified. The build does not modify TCC or weaken the signing requirement.

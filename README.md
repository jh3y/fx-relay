<p align="center"><img src="docs/brand/hero.svg" alt="FX Relay — native macOS control for the FX-MIC" width="100%"></p>

A small native macOS utility that turns the **Teenage Engineering EP-2350 FX-MIC** into a configurable controller for your apps.

Squeeze the handle to gate your microphone. Play a sample to send a key, shortcut or command. Choose a profile for your workflow. **Your agent or dictation app handles speech; the bridge only turns signals into actions.**

**macOS 15+ · Swift / SwiftUI · Four banks · Sixteen samples · Per-bank handle actions · Local profiles**

**Made possible by [tink-agent](https://github.com/tajchert/tink-agent), by Michal Tajchert.** Its exploration of the FX-MIC as an agent controller and its sample/pitch configuration were the starting point for this project. FX Relay builds on that inspiration with a focused native controller, diagnostic tooling and configurable workflows. [Acknowledgements and reference license →](THIRD_PARTY_NOTICES.md)

[Get started](docs/GETTING_STARTED.md) · [Profiles](docs/PROFILES.md) · [Dictation options](docs/VOICE_OPTIONS.md) · [Managed Macs / CLI](docs/MANAGED_MACS.md) · [Build](docs/DEVELOPMENT.md) · [Progress](docs/HISTORY.md)

<img src="docs/previews/v0.8.0/menu-light.png" alt="FX Relay Contact popover in light mode" width="38%"> <img src="docs/previews/v0.8.0/menu-dark.png" alt="FX Relay Contact popover in dark mode" width="38%">

*Actual SwiftUI views rendered offscreen with an isolated Agent Banks fixture. Light and dark appearance follow macOS. These images demonstrate layout, not a live hardware test.*

## A mic with something extra

- **One setup, four banks.** Install the standard cue pack from the app. Pick an FX bank and sample slot on the mic; PLAY fires the configured action.
- **A handle action per bank.** Give FX 1 a key hold and FX 2 no keyboard action, or configure all four independently. A sample identifies the bank after switching FX.
- **Your controls, your mappings.** Hold Key, Hold Key — Continuous, Keystroke, Shortcut, Type Text, optional delayed Enter, or None. Record shortcuts directly in the editor.
- **Starter workflows.** Codex, Claude Code · Tap, Apple Dictation and Agent Banks are included. Duplicate, rename, edit and share profiles as JSON.
- **See what the mic is doing.** Live RMS/peak, amplitude history, spectrum, cue counters and event logs. Diagnostic exports contain measurements, not audio recordings.
- **Ready when your app is.** Output follows the focused app automatically. One Pause/Resume control lives in the menu bar; there is no enable countdown.
- **A small macOS utility.** Contact icon and menu-bar status symbol, adaptive light/dark materials, explicit input selection and background analysis. No account or package dependencies.
- **Setup you can follow.** Guided permissions, live input checks, optional cue installation and workflow selection. Ready means capture and keyboard permissions are available.
- **Keep your controls in view.** A compact four-bank reference, optional Keep on Top, brief detection highlights and opt-in Launch at Login.

## Get started

1. Build using the commands below, then move **FX Relay.app** from `dist` into **Applications**, your personal `~/Applications` folder, or another stable folder you own. Open that copy. First-run Setup guides Microphone and Accessibility permissions; the app lives in the menu bar.
2. Connect the mic's analogue output to a compatible input adapter and select that adapter in the menu bar. Configure your target app's microphone separately.
3. For initial setup, connect USB-C and expose **FX MIC DISK**. Open **Setup → Cue pack → Choose FX MIC DISK**. Review the inspection, then **Install Four Banks**. Existing known packs can be upgraded; custom files are left for review. The app keeps a local backup.
4. Eject the disk in Finder so the mic reloads the pack. Resume from the menu bar and open Signal Monitor to check each sample. Output is suspended while the bridge has focus.
5. Choose a starter profile and configure its target app. Focus a blank test document: output is ready automatically after a brief quiet interval.

[Full setup and hardware check →](docs/GETTING_STARTED.md)

## Start with a profile

| Profile | Base bank samples 1–4 | Setup |
| --- | --- | --- |
| **Codex** | Return · F8 voice toggle · Escape · Control+C | Requires a Codex CLI build/session supporting voice |
| **Claude Code · Tap** | Return · Space record/send · Escape · Control+C | Enable `/voice tap`; the second Space can submit the prompt |
| **Apple Dictation** | ⌃⌥D dictation toggle · Escape · Return · Undo | Set the same shortcut in macOS Keyboard settings |

Those three leave the handle's keyboard mapping off: the handle still gates the analogue mic. Every mapping is editable, and generic Hold-Space, Command Voice, Blank and Dictation Shortcut templates are also available. Text commands in starter profiles leave automatic Enter off.

The second bank supplies commands such as `/voice` and `/compact`; the third provides navigation keys. The fourth is available for your own mappings. Apple Dictation repeats its four shortcuts across all banks. [View all defaults and compatibility notes →](docs/PROFILES.md)

**Agent Banks** puts Claude in FX 1, Codex in FX 2 and Dictation in FX 3 within one profile. New copies use continuous Hold Space in FX 1 and no handle key elsewhere. Enable `/voice hold` in Claude first. Existing saved profiles retain their mappings; choose **Hold Key — Continuous** explicitly when upgrading. Choose a bank → **Handle** to edit it. Sample 4 is unassigned in every bank so it can identify that bank without sending a macro. [Bank routing and handle checks →](docs/PROFILES.md#handle-actions-per-bank)

## How it works

```text
FX-MIC → audio adapter → local signal analysis → control event → configured action
            └────────→ your agent / dictation app receives its own mic input
```

The orange button selects an FX preset. The sample selector chooses one of four slots. PLAY emits its cue. Pitch-shifted presets give the same samples different identities across four banks. No-FX and FX 1 share a bank. The app starts in **Base / FX 1**, visibly labelled as the startup bank. Play a sample after changing FX: its cue updates the current bank and handle mapping. You can also choose Current bank in the menu bar. Silent selector changes cannot be observed; the startup bank is a default, not a measurement.

The bridge does not transcribe, route, mute, replace or upload your audio. Cue sounds remain in the signal heard by your other apps.

## Running in the background

FX Relay is designed to stay in the menu bar. Closing its windows leaves capture and control detection running; **Pause** stops both, and **Quit** exits. It runs no speech model. Chart updates are limited to visible surfaces, while signal analysis continues in the background.

With the windows and popover closed and capture running, **v0.7.0 on an Apple M2 Max** averaged **4.53% of one CPU core and 83 MiB resident memory** over 30.25 seconds. CPU uses process CPU-time deltas (100% = one core); memory is RSS. Speech and room noise were uncontrolled. This is a short observation on one Mac, not a battery-life or long-duration benchmark; devices and visible diagnostic views can change the cost.

## Current status

This is a working development build, with these boundaries:

- The user reports successful everyday use in both Codex and Claude with v0.7.0. That is useful workflow evidence, alongside the automated checks, rather than a compatibility claim for every terminal or voice configuration.

- Base and FX 2 cue frequencies have been measured on hardware. The user reports successful presses across all sixteen slots, including a custom `/voice` action in bank 4. Generated-cue tests cover all sixteen targets; this does not establish voice compatibility in every FX mode.
- Voice transcription was reported to stop in FX 3/4 and resume in the base bank. The cause is unconfirmed; use the base bank for voice until the [voice-bank check](docs/VOICE_BANK_CHECK.md) separates hardware behavior from keyboard actions. Cue recognition alone does not establish voice compatibility.
- Handle keyboard output follows sound activity. A quiet pause can release a key while the handle remains squeezed; it is not a direct hardware-switch sensor.
- **Hold Key** sends one down/up pair. **Hold Key — Continuous** adds repeated key-down events for terminal hold modes such as Claude's `/voice hold`. Repeats stop on signal release, focus loss, capture failure or output disable. A native iTerm2 receipt test verifies all 41 Space presses from one continuous hold reach the terminal. The user confirmed Claude starts listening with the handle in v0.6.3. First-word capture and other terminal setups remain unverified. The Claude Code · Tap starter remains a separate workflow.
- Output starts ready once input and permissions are available. Focus, profile, permission and capture changes release held keys; fresh output resumes automatically after quiet. Pause persists across launches. Independent held-key leases provide a release timeout. Force-kill/OS failure cannot run normal cleanup.
- Development builds support a stable local signing identity, with an ad-hoc fallback when unconfigured. Developer ID signing and notarization remain a distribution step; no public binary release is claimed here.

## Build it

Requires macOS 15+, an installed Swift toolchain, and full Xcode for tests.

```sh
git clone https://github.com/jh3y/fx-relay.git
cd fx-relay
./script/build_and_run.sh --build-only
```

Move `dist/FX Relay.app` into Applications or a folder you own, then open it. It runs in the menu bar and intentionally has no Dock icon. Keep one installed copy and open that same copy consistently. Running the build script without `--build-only` instead opens the development copy in `dist`. Builds use release optimization and two compiler jobs by default. For fewer permission renewals during development, configure [local signing](docs/SIGNING.md) before building.

**Pause** stops audio monitoring and actions; **Quit** closes the app and releases its held keys. To uninstall, disable **Launch at Login** if enabled, quit, and move the app to the Trash. Preferences and mic backups remain available. The login option registers the main app; no separate helper is installed. Uninstalling the Mac app does not restore the mic's hardware configuration. See [removal details](docs/MANAGED_MACS.md#stopping-and-removing-the-app).

```sh
swift test --jobs 2 --configuration release
python3 -m unittest discover -s Tests/DeviceSetupTests -v
```

[Development, architecture and validation →](docs/DEVELOPMENT.md)

## Made to be yours

Profiles are local JSON configuration, independent of your agent or dictation service. Importing one selects a new local copy; review its mappings before returning to your app. Imports cannot change the microphone or resume a paused bridge. No automatic profile switching, shell-command execution, speech model or cloud connection is built into the bridge.

[Contributing](CONTRIBUTING.md) · [Brand assets](docs/BRANDING.md) · [Acknowledgements](THIRD_PARTY_NOTICES.md)

Released under the [MIT license](LICENSE). The project was previously called FX-MIC Bridge. This is an independent project, not affiliated with Teenage Engineering, Apple, OpenAI or Anthropic.

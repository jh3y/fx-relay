# Running FX Relay on a work Mac

FX Relay can run from a user-owned folder without copying it to `/Applications`. That is useful when the only restriction is the lack of administrator installation rights. It still executes software on the Mac, so the organization's application policy and macOS privacy controls apply.

## Terminal launch today

Keep the whole app bundle together. For example, after placing an approved copy in your user Applications folder:

```sh
open "$HOME/Applications/FX Relay.app"
```

From a source checkout with an approved Swift toolchain, the existing build command builds and opens the bundle in that checkout:

```sh
./script/build_and_run.sh
```

Neither command requires a system-wide installer. Both start the **menu-bar app**. They do not enable a terminal-only mode or change the permission requirements. Keep the bundle in a stable location so its identity and settings are straightforward to manage.

The current development bundle is ad-hoc signed, not Developer ID signed or notarized. A downloaded copy may therefore be blocked. Apple documents the distinction between developer identity, notarization and administrator-controlled launch settings in [Safely open apps on your Mac](https://support.apple.com/en-us/102445).

## What permissions remain necessary?

- **Microphone:** to measure the selected audio input. The bridge cannot detect the handle's signal or sample cues without it. Apple's [media-capture authorization documentation](https://developer.apple.com/documentation/bundleresources/requesting-authorization-for-media-capture-on-macos) describes this consent requirement.
- **Accessibility / event posting:** to synthesize keyboard actions. The current implementation checks Accessibility trust and uses CoreGraphics events.
- **Access to the removable mic volume:** only when installing or restoring the cue pack. Once configured on an approved machine, the mic's analogue control signals do not require its USB disk to stay mounted.

Device management can restrict microphone access and control Accessibility/event-posting permissions. A CLI executable remains subject to these controls; it does not inherit unlimited permissions from a terminal. See Apple's [Privacy Preferences Policy Control settings](https://support.apple.com/guide/deployment/privacy-preferences-policy-control-payload-dep38df53c2a/web). An IT team can decide whether this tool and its permissions are allowed. Developer ID signing and notarization would make distribution and identification more consistent, but do not override organizational policy.

For an IT review: the bundle identifier is `com.jhey.fxmicbridge` (retained from the original name). FX Relay measures audio locally, has no transcription or networking client, does not change the system input device, and starts with keyboard output off. Profiles can send configured keys, shortcuts and text to the focused target after explicit arming. No root helper, background system daemon or system extension is required by the implementation.

## A future terminal-only mode

A true headless mode is feasible: it could load the same JSON profiles, select an input device, print detection logs, require explicit arming and release keys on exit. It would reuse the audio analyzer, detectors and action dispatcher, with separate permission and lifecycle testing.

**That mode is not implemented in v0.5.0.** Launching the raw executable or using `swift run` is not a documented substitute for the bundle and its permission metadata/resources. A CLI would improve scripting and deployment convenience, not remove microphone, keyboard or company approval requirements.

If additional software is not allowed, the FX-MIC can still work as a normal analogue microphone with its physical handle gate in an approved application. Programmable audio-cue actions require an approved detector such as FX Relay running on the computer.

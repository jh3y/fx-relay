# Voice and dictation profiles

FX Relay sends configurable keyboard actions. The target app handles speech recognition, microphone selection and text insertion. No dictation engine is bundled with FX Relay.

## Agent voice

Choose a starter profile in FX Relay, then match its mappings to the voice mode configured in your agent. Profiles are editable examples; shortcuts and voice behavior vary between apps and versions. See [profiles and mappings](PROFILES.md) for action types and per-bank handle settings.

## Apple Dictation

1. Enable Dictation in macOS System Settings → Keyboard.
2. Select the audio adapter connected to the FX-MIC as Dictation's microphone source.
3. Set the Dictation shortcut to **Control–Option–D** and choose the Apple Dictation profile in FX Relay.
4. Test the shortcut in an empty text document, then use sample 1 to send the same shortcut through FX Relay.

The supplied profile leaves the handle keyboard action unassigned; the physical handle still gates the microphone. Check the active processing mode and language requirements in macOS Keyboard settings. [Apple's Dictation guide](https://support.apple.com/en-gb/guide/mac-help/mh40584/26/mac/26).

## Other dictation apps

Use the Dictation Shortcut starter and configure a matching shortcut in your chosen app. For a global hotkey, choose **Shortcut → macOS system shortcut** delivery. Start with an ordinary modifier-plus-key toggle shortcut and verify it before configuring a hold action; modifier-only shortcuts and synthetic events are not supported uniformly by every app.

Select the FX-MIC audio adapter inside the dictation app. Stop other voice sessions while testing, since multiple apps can listen to the same microphone. Cue sounds remain audible to those apps: FX Relay does not filter or route the signal.

For the reported FX 3/4 voice issue, see the [voice-bank check](VOICE_BANK_CHECK.md). Recognizing a control cue does not establish that a bank is suitable for speech.

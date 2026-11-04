# Choosing who handles speech

The bridge is a controller. Any transcription, model, account, privacy policy or processing delay belongs to the chosen voice application. No dictation product is installed with the bridge.

| Option | Why try it | Bridge setup |
| --- | --- | --- |
| Apple Dictation | Built into macOS; a straightforward first experiment across editable text fields | Included profile; match a custom system shortcut |
| Codex voice | Fits sessions already using Codex's voice conversation | Included CLI starter; F8 or editable commands |
| Claude Code voice | Coding vocabulary and dictation inside the terminal | Included Tap starter; review its submission behavior |
| MacWhisper | Local-model transcription plus system-wide dictation and optional text processing | Dictation Shortcut template; match its configured hotkey |
| Superwhisper | Local/offline options, vocabulary and modes for text formatting | Dictation Shortcut template; configure a matching toggle shortcut |
| Wispr Flow | Another option focused on cleaning up dictated text across apps | Configure a supported ordinary shortcut and test it; no bundled verified profile |

**Start with Apple Dictation** if the aim is to try a consistent input method without installing another app. Check its accuracy on your filenames and technical vocabulary before choosing a paid service. Whether processing is on-device, available offline, or supported in a language depends on the Mac/settings; Apple's Keyboard settings describe the active processing mode. [Apple Dictation](https://support.apple.com/en-gb/guide/mac-help/mh40584/26/mac/26).

MacWhisper supports local models and dictation. Its support guide says system-wide Dictation is in the directly distributed version, not the App Store edition. [MacWhisper](https://www.macwhisper.com/) · [Dictation setup](https://docs.macwhisper.com/article/14-how-to-use-the-dictation-feature).

Superwhisper documents offline operation, custom vocabulary, modes and automatic text insertion. Those features may suit a workflow that needs more formatting control. [Superwhisper](https://superwhisper.com/).

Wispr Flow markets text cleanup across apps. Treat it as a separate service with its own connection, privacy and plan requirements; check those before adopting it. [Wispr Flow](https://wisprflow.ai/).

These are feature comparisons, not measured accuracy or latency rankings. None has been benchmarked with this mic in the current build. Compare a short representative sentence, time from finishing speech to inserted text, and whether the app keeps focus and receives the bridge's synthetic shortcut. Cue sounds also reach the dictation app because the bridge does not filter the mic signal.

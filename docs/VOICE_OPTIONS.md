# Choosing who handles speech

The bridge is a controller. Any transcription, model, account, privacy policy or processing delay belongs to the chosen voice application. No dictation product is installed with the bridge.

| Option | Why try it | Bridge setup |
| --- | --- | --- |
| Apple Dictation | Built into macOS; a straightforward first experiment across editable text fields | Included profile; match a custom system shortcut |
| Hex | Local dictation with configurable shortcuts and speech models; macOS, Windows and Linux | Candidate integration: use a sample-triggered system shortcut in Tap mode; not yet verified with FX Relay |
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

## Apple Dictation or Hex?

**Apple Dictation is the easiest baseline.** It is already in macOS and supports a custom start/stop shortcut and a selected microphone. To try the included profile, enable Dictation in System Settings → Keyboard, choose the FX-MIC audio adapter, set its shortcut to **Control–Option–D**, then select the Apple Dictation profile in FX Relay. Test sample 1 in an empty text document before an agent prompt. Keyboard settings explain whether the selected language/configuration uses on-device processing or needs a connection. [Apple’s guide](https://support.apple.com/en-gb/guide/mac-help/mh40584/26/mac/26).

**Hex is a promising next comparison for a uniform workflow across apps.** Its standard dictation flow downloads a speech model, recognises speech locally, and pastes at the current focus. The repository is MIT licensed; the macOS download targets Apple silicon and macOS 15+. It remains a separate app with its own model, memory and transcription workload. [Hex](https://anoma.ly/hex/) · [Repository](https://github.com/anomalyco/hex).

The reviewed development source supports Hold, Tap and double-tap variants, custom shortcuts and local model selection. Features on the development branch may differ from a stable download. Our first integration experiment would use **Tap**, an ordinary modifier-plus-key shortcut, and FX Relay’s **Shortcut → macOS system shortcut** delivery on a sample. That avoids relying on the default modifier-only Option hold. This is a proposed test, not verified compatibility; the existing process-targeted continuous Space action is for terminal PTT. [Shortcut modes](https://github.com/anomalyco/hex/blob/159129ed2991fd7fc9b6799528dfd4463177cd0b/src/rune_ui/shortcut_mode.rs) · [Dictation behavior](https://github.com/anomalyco/hex/blob/159129ed2991fd7fc9b6799528dfd4463177cd0b/docs/features/dictation.md).

There is no measured accuracy or latency winner here. Compare the same short passages containing filenames, commands and punctuation in both apps. Measure the delay from the last word until usable text appears, count corrections, and check insertion into the actual terminal. Neither option is necessary if your existing agent voice mode already meets your needs.

## A small, repeatable comparison

Open [the local comparison sheet](dictation-check.html) from a source checkout in your browser. It receives text from the dictation app, keeps trials in the page until closed, and exports a JSON report. It does not access the microphone, transcribe, use a model or send anything over the network. A GitHub file preview will show its source; download/open the HTML to use it.

1. Stop voice listening in other apps, including agent sessions. A separate dictation tool will not prevent another listening app from hearing the same mic.
2. Start with Apple Dictation. Choose the FX-MIC audio adapter in its settings and use the included FX Relay Apple Dictation profile, with the matching Control–Option–D system shortcut. Keep the mic in the base bank for this comparison, given the unresolved voice behavior in FX 3/4.
3. On the comparison sheet, select Apple Dictation and a passage, then press **Start trial**. With the text area focused, start dictation, squeeze the handle and read the passage, release, then stop dictation. First establish that the ordinary keyboard shortcut works; repeat using the mapped sample to check bridge compatibility separately.
4. Save the uncorrected result. Optionally note corrections needed and the perceived delay from the last word to the complete usable text. The sheet does not measure that delay automatically: Apple may stream text while another app inserts everything on stop.
5. Repeat for Hex, using the same adapter, passage and mic bank. Quit the other dictation app or remove its conflicting shortcut first. Record the Hex version and local model. Check the stable app's available shortcut modes; try a normal modifier-plus-key combination in Tap mode with FX Relay's system-shortcut delivery if available.

Run each passage three times per app before drawing an accuracy conclusion. Then try the preferred option in an empty terminal prompt, with automatic submission off. Compare insertion, focus, corrections, delay and whether the cue itself creates stray text. Export the report when finished; it contains the dictated text, so review it before sharing.

**Evaluation status, 2026-11-06:** Hex 3.3.0 was downloaded from its official release, checked against the published SHA-256, and passed strict code-signature and Gatekeeper checks. It was installed on the evaluation Mac, but its first-run setup, local model and actual dictation trials remain pending. Neither Apple Dictation nor Hex has yet been verified with FX Relay's synthetic shortcut in this comparison. [Release](https://github.com/anomalyco/hex/releases/tag/v3.3.0).

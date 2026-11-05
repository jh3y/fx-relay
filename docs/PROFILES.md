# Starter profiles

Codex, Claude Code · Tap, Apple Dictation and Agent Banks are added on first use. On upgrade, they are added once without changing the selected profile or its mappings. Deleted starters are not recreated on every launch; use **… → New from Template** to add another copy. All templates use the four-bank pack. Existing profiles retain their bank switches.

Open Edit Mappings, choose the profile, select a bank and sample, edit its action, then Apply Changes. The profile menu also offers Rename, Duplicate, Delete, Import JSON and Export JSON. Each bank has Samples and Handle tabs. Handle banks gives an overview of all four handle mappings; Detection contains the sound thresholds and timing. Editing disables output; profile switching is unavailable while changes are unapplied. Closing the editor discards its draft.

## Handle actions per bank

A profile contains four banks, each with four sample actions and its own handle action. Choose a bank, open **Handle**, select an action and Apply Changes. **None** leaves the handle as a physical microphone gate without sending keys. The bank's **Samples** switch controls sample actions only. Detection runs even when the handle action is None or keyboard output is off.

The handle bank follows the last recognized sample. After pressing the silent orange selector, **play a sample in the new bank before using its handle mapping**. An unassigned sample still identifies its bank without firing a macro. The app cannot observe a silent FX change; until a new cue arrives, it retains the last detected bank. No-FX and FX 1 share the first bank.

You can also choose **Handle bank** explicitly in the menu bar or Signal Monitor. Manual selection disarms keyboard output; arm again in your target app. The next sample replaces that selection. A restart or capture reset forgets the bank. When handle mappings differ, an unknown bank sends no handle action. If all four mappings are identical, that common mapping works without identifying a bank.

Changing bank or mapping releases held keys and cancels pending typing/Enter. The detector must observe quiet before a fresh sound activation can fire the new handle action. Profile changes also disarm output. Editing the bank shown in the mapping window does not select the live handle bank.

**This remains sound-based detection.** A silent squeeze may show no change. Speaking must exceed the PTT activation threshold for the confirmation interval; silence can release the key even while the handle stays squeezed. The Signal Monitor separately shows sound-detector state, the selected handle action and whether a key was posted. Its manual TEST SPACE counters count only that button's test events. See the [handle check](GETTING_STARTED.md#4-check-handle-detection-separately).

## Agent Banks

| Bank | Handle | Samples 1–4 |
| --- | --- | --- |
| No-FX / FX 1 · Claude | Hold Space — Continuous | Return · Escape · Control+C · None |
| FX 2 · Codex | None | F8 · Return · Escape · None |
| FX 3 · Dictation | None | ⌃⌥D system shortcut · Return · Escape · None |
| FX 4 | None | All unassigned |

Sample 4 can identify any bank without sending a macro. This starter is added once on upgrade without changing the selected profile or existing mappings. It does not switch applications. Configure Apple Dictation's shortcut and check Codex voice support as described below. New copies use continuous Space in FX 1. Older saved copies retain their single-hold setting: change the bank's Handle action to **Hold Key — Continuous**. Run `/voice hold` in Claude before arming. Live compatibility still requires checking in your terminal. Use the separate Claude Code · Tap workflow when a toggle is preferred.

## Codex

Base: Return, F8, Escape, Control+C. FX 2: `/voice`, `/voice mute`, `/compact`, `/help`, all typed without Enter. FX 3: Tab, Shift+Tab, Up, Down. FX 4: unassigned. Handle: no key.

F8 and `/voice` start/stop voice only when supported by the CLI build and session. Desktop voice uses its separately configured hotkey; record that instead if desired. These defaults do not assume the app accepts hold Space. See [Codex CLI commands](https://learn.chatgpt.com/docs/developer-commands?surface=cli) and [desktop Voice](https://learn.chatgpt.com/docs/features/voice).

## Claude Code · Tap

Base: Return, Space, Escape, Control+C. FX 2: `/voice tap`, `/voice off`, `/compact`, `/help`, typed without Enter. FX 3: Tab, Shift+Tab, Up, Down. FX 4: unassigned. Handle: no key.

Enable `/voice tap` in Claude first. With an empty prompt, Space starts recording; another Space stops and can submit the prompt. Claude's documented tap mode auto-submits transcripts of at least three words. This is target-app behavior, independent of the bridge's optional Enter setting.

Claude's terminal hold mode relies on repeated key events. The bridge's Hold Key action intentionally emits a single down/up pair, so the starter uses tap mode. [Claude voice documentation](https://code.claude.com/docs/en/voice-dictation) describes the account/microphone requirements, recording modes and submission behavior. Actual operation with synthesized events remains a live compatibility check.

## Claude Code · continuous hold

In your chosen profile, select the Claude bank → **Handle** → **Hold Key — Continuous** → **Space**, then Apply Changes. In Claude, run `/voice hold`. Arm keyboard output and focus the Claude terminal during the countdown, then wait quietly before speaking while squeezing. With differing bank mappings, first identify the bank by playing a sample or explicitly selecting Handle bank in Signal Monitor.

Ordinary Hold Key emits one down and one up. Continuous hold emits one initial down, marked autorepeat key-down events while active, then one up. Fresh control frames supply approximately 25 repeats per second; a late frame never produces a catch-up burst. There is no repeat timer running in the background. Focus, Accessibility, audio freshness and the independent release timeout still apply. The event log identifies continuous holds and includes the total repeats when releasing.

This follows Claude's documented key-repeat requirement. It is not speech recognition in FX Relay. Sound-based activation and Claude's own warmup can miss the beginning of speech; pauses longer than the release delay stop the hold. Repeats continue during that delay, initially 900 ms. An ordinary text field will receive repeated spaces/characters, just as when a key repeats on a keyboard. Native event flags and cancellation are tested; live terminal acceptance remains a separate check.

## Apple Dictation

Each bank: ⌃⌥D, Escape, Return, Command+Z. Handle: no key.

Enable Dictation under System Settings → Keyboard, choose the FX-MIC adapter, and customize its shortcut to Control+Option+D. Alternatively, record your chosen combination in the sample action. Sample 1 uses **Send to macOS / system shortcut**.

Arm output, focus a blank text field, and play sample 1. Wait for Apple's indicator, then hold the handle while speaking. Release the handle and play sample 1 again to finish. This toggles dictation; the handle mechanically gates sound. Apple performs transcription. See [Apple's guide](https://support.apple.com/guide/mac-help/use-dictation-mh40584/mac). System-shortcut receipt, focus retention and target-app insertion need a live test.

## Other templates and sharing

**Dictation Shortcut** uses the same editable shortcut layout for MacWhisper, Superwhisper or another app. Configure one service to own that shortcut. **Hold-Space Voice** is available for applications accepting a down/up hold; its handle detection follows sound and can release during silence. **Command Voice** supplies editable slash-command examples. **Blank** starts empty.

Actions: None, Hold Key, Hold Key — Continuous, Keystroke, Shortcut and Type Text. Hold Key releases on the inferred handle release or sample ending. Text is one line with optional delayed Enter, disabled by default in starters. The bridge never executes shell commands. Ordinary actions target the armed app; explicit system shortcuts enter the macOS event stream.

Profile JSON schema 4 is exported; schemas 1–3 remain importable. Older profiles inherit their previous effective handle mapping in all four banks. The app saves the upgraded library under `bridge.profiles.v5`, leaving previous library bytes intact for older versions. Imports are validated and added as new copies, never silently overwriting an existing profile. They cannot arm output, select an input or write mic files. The example JSON files in [profiles/](../profiles/) are generated from the same Swift templates used in the app.

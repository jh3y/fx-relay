# Starter profiles

Codex, Claude Code · Tap, Apple Dictation and Agent Banks are added on first use. On upgrade, they are added once without changing the selected profile or its mappings. Deleted starters are not recreated on every launch; use **… → New from Template** to add another copy. All templates use the four-bank pack. Existing profiles retain their bank switches.

Open Edit Mappings, choose the profile, select a bank and sample, edit its action, then Apply Changes. The profile menu also offers Rename, Duplicate, Delete, Import JSON and Export JSON. Each bank has Samples and Handle tabs. Handle banks gives an overview of all four handle mappings; Detection contains the sound thresholds and timing. Unapplied edits suspend output until applied or reverted; profile switching is unavailable while changes are unapplied. Closing the editor discards its draft.

## Handle actions per bank

A profile contains four banks, each with four sample actions and its own handle action. Choose a bank, open **Handle**, select an action and Apply Changes. **None** leaves the handle as a physical microphone gate without sending keys. The bank's **Samples** switch controls sample actions only. Detection runs even when the handle action is None or keyboard output is off.

The app starts with Base / FX 1 as an explicit startup default, then the handle bank follows the last recognized sample. After pressing the silent orange selector, **play a sample in the new bank before using its handle mapping**. An unassigned sample still identifies its bank without firing a macro. The app cannot observe a silent FX change; until a new cue arrives, it retains the last detected bank. No-FX and FX 1 share the first bank.

You can also choose **Current bank** explicitly in the menu bar. The next sample replaces that selection. Restarting or reconnecting returns to the labelled Base / FX 1 startup default. Editing mappings preserves the known bank if cue frequencies have not changed. The default does not claim to read the physical FX lights.

Changing bank or mapping releases held keys and cancels pending typing/Enter. The detector must observe quiet before a fresh sound activation can fire the new handle action. Output resumes automatically in the focused app after quiet. Editing the bank shown in the mapping window does not select the live handle bank.

**This remains sound-based detection.** A silent squeeze may show no change. Speaking must exceed the PTT activation threshold for the confirmation interval; silence can release the key even while the handle stays squeezed. The Signal Monitor separately shows sound-detector state, the selected handle action and whether a key was posted. Its manual TEST SPACE counters count only that button's test events. See the [handle check](GETTING_STARTED.md#4-check-handle-detection-separately).

## Agent Banks

| Bank | Handle | Samples 1–4 |
| --- | --- | --- |
| No-FX / FX 1 · Claude | Hold Space — Continuous | Return · Escape · Control+C · None |
| FX 2 · Codex | None | F8 · Return · Escape · None |
| FX 3 · Dictation | None | ⌃⌥D system shortcut · Return · Escape · None |
| FX 4 | None | All unassigned |

Sample 4 can identify any bank without sending a macro. This starter is added once on upgrade without changing the selected profile or existing mappings. It does not switch applications. Configure Apple Dictation's shortcut and check Codex voice support as described below. New copies use continuous Space in FX 1. Older saved copies retain their single-hold setting: change the bank's Handle action to **Hold Key — Continuous**. Run `/voice hold` in Claude first. Live compatibility still requires checking in your terminal. Use the separate Claude Code · Tap workflow when a toggle is preferred.

## Codex

Base: Return, F8, Escape, Control+C. FX 2: `/voice`, `/voice mute`, `/compact`, `/help`, all typed without Enter. FX 3: Tab, Shift+Tab, Up, Down. FX 4: unassigned. Handle: no key.

F8 and `/voice` start/stop voice only when supported by the CLI build and session. Desktop voice uses its separately configured hotkey; record that instead if desired. These defaults do not assume the app accepts hold Space. See [Codex CLI commands](https://learn.chatgpt.com/docs/developer-commands?surface=cli) and [desktop Voice](https://learn.chatgpt.com/docs/features/voice).

## Claude Code · Tap

Base: Return, Space, Escape, Control+C. FX 2: `/voice tap`, `/voice off`, `/compact`, `/help`, typed without Enter. FX 3: Tab, Shift+Tab, Up, Down. FX 4: unassigned. Handle: no key.

Enable `/voice tap` in Claude first. With an empty prompt, Space starts recording; another Space stops and can submit the prompt. Claude's documented tap mode auto-submits transcripts of at least three words. This is target-app behavior, independent of the bridge's optional Enter setting.

Claude's terminal hold mode relies on repeated key events. The bridge's Hold Key action intentionally emits a single down/up pair, so the starter uses tap mode. [Claude voice documentation](https://code.claude.com/docs/en/voice-dictation) describes the account/microphone requirements, recording modes and submission behavior. Actual operation with synthesized events remains a live compatibility check.

## Claude Code · continuous hold

In your chosen profile, select the Claude bank → **Handle** → **Hold Key — Continuous** → **Space**, then Apply Changes. In Claude, run `/voice hold`. Focus the Claude terminal, then squeeze and begin speaking after a quiet moment. Do not wait for Claude’s listening indicator before speaking: the bridge needs sound to detect the handle. Base / FX 1 is the startup default; after changing FX, play a sample or choose Current bank in the menu bar.

Ordinary Hold Key emits one down and one up. Continuous hold emits one initial down, repeated key-down events while active, then one up. Fresh control frames supply approximately 25 repeats per second; a late frame never produces a catch-up burst. There is no repeat timer running in the background. Focus, Accessibility, audio freshness and the independent release timeout still apply. The event log identifies continuous holds and includes the total repeats when releasing.

This follows Claude's documented key-repeat requirement. It is not speech recognition in FX Relay. Sound-based activation and Claude's own warmup can miss the beginning of speech; pauses longer than the release delay stop the hold. Repeats continue during that delay, initially 900 ms. An ordinary text field will receive repeated spaces/characters, just as when a key repeats on a keyboard. The terminal receipt check verifies 41/41 Spaces using process-targeted ordinary key-down events. Marking those targeted events as native autorepeat delivered only the first Space on the development Mac, which is why v0.6.3 changes that flag. The user confirmed Claude listening starts with the handle in v0.6.3 after microphone access was renewed. First-word capture and other terminal setups remain separate checks.

## Apple Dictation

Each bank: ⌃⌥D, Escape, Return, Command+Z. Handle: no key.

Enable Dictation under System Settings → Keyboard, choose the FX-MIC adapter, and customize its shortcut to Control+Option+D. Alternatively, record your chosen combination in the sample action. Sample 1 uses **Send to macOS / system shortcut**.

Focus a blank text field and play sample 1. Wait for Apple's indicator, then hold the handle while speaking. Release the handle and play sample 1 again to finish. This toggles dictation; the handle mechanically gates sound. Apple performs transcription. See [Apple's guide](https://support.apple.com/guide/mac-help/use-dictation-mh40584/mac). System-shortcut receipt, focus retention and target-app insertion need a live test.

## Other templates and sharing

**Dictation Shortcut** uses the same editable shortcut layout for MacWhisper, Superwhisper or another app. Configure one service to own that shortcut. **Hold-Space Voice** is available for applications accepting a down/up hold; its handle detection follows sound and can release during silence. **Command Voice** supplies editable slash-command examples. **Blank** starts empty.

Actions: None, Hold Key, Hold Key — Continuous, Keystroke, Shortcut and Type Text. Hold Key releases on the inferred handle release or sample ending. Text is one line with optional delayed Enter, disabled by default in starters. The bridge never executes shell commands. Ordinary actions target the focused app; explicit system shortcuts enter the macOS event stream.

Profile JSON schema 4 is exported; schemas 1–3 remain importable. Older profiles inherit their previous effective handle mapping in all four banks. The app saves the upgraded library under `bridge.profiles.v5`, leaving previous library bytes intact for older versions. Imports are validated and added as new copies, never silently overwriting an existing profile. Importing selects the new copy but does not resume a paused bridge, select an input or write mic files. The example JSON files in [profiles/](../profiles/) are generated from the same Swift templates used in the app.

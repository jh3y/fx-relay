# Starter profiles

Codex, Claude Code · Tap and Apple Dictation are added on first use. On upgrade, they are added once without changing the selected profile or its mappings. Deleted starters are not recreated on every launch; use **… → New from Template** to add another copy. All templates use the four-bank pack. Existing profiles retain their bank switches.

Open Edit Mappings, choose the profile, select a bank and sample, edit its action, then Apply Changes. The profile menu also offers Rename, Duplicate, Delete, Import JSON and Export JSON. Handle and Detection have separate pages. Editing disables output; profile switching is unavailable while changes are unapplied. Closing the editor discards its draft.

## Codex

Base: Return, F8, Escape, Control+C. FX 2: `/voice`, `/voice mute`, `/compact`, `/help`, all typed without Enter. FX 3: Tab, Shift+Tab, Up, Down. FX 4: unassigned. Handle: no key.

F8 and `/voice` start/stop voice only when supported by the CLI build and session. Desktop voice uses its separately configured hotkey; record that instead if desired. These defaults do not assume the app accepts hold Space. See [Codex CLI commands](https://learn.chatgpt.com/docs/developer-commands?surface=cli) and [desktop Voice](https://learn.chatgpt.com/docs/features/voice).

## Claude Code · Tap

Base: Return, Space, Escape, Control+C. FX 2: `/voice tap`, `/voice off`, `/compact`, `/help`, typed without Enter. FX 3: Tab, Shift+Tab, Up, Down. FX 4: unassigned. Handle: no key.

Enable `/voice tap` in Claude first. With an empty prompt, Space starts recording; another Space stops and can submit the prompt. Claude's documented tap mode auto-submits transcripts of at least three words. This is target-app behavior, independent of the bridge's optional Enter setting.

Claude's terminal hold mode relies on repeated key events. The bridge's Hold Key action intentionally emits a single down/up pair, so the starter uses tap mode. [Claude voice documentation](https://code.claude.com/docs/en/voice-dictation) describes the account/microphone requirements, recording modes and submission behavior. Actual operation with synthesized events remains a live compatibility check.

## Apple Dictation

Each bank: ⌃⌥D, Escape, Return, Command+Z. Handle: no key.

Enable Dictation under System Settings → Keyboard, choose the FX-MIC adapter, and customize its shortcut to Control+Option+D. Alternatively, record your chosen combination in the sample action. Sample 1 uses **Send to macOS / system shortcut**.

Arm output, focus a blank text field, and play sample 1. Wait for Apple's indicator, then hold the handle while speaking. Release the handle and play sample 1 again to finish. This toggles dictation; the handle mechanically gates sound. Apple performs transcription. See [Apple's guide](https://support.apple.com/guide/mac-help/use-dictation-mh40584/mac). System-shortcut receipt, focus retention and target-app insertion need a live test.

## Other templates and sharing

**Dictation Shortcut** uses the same editable shortcut layout for MacWhisper, Superwhisper or another app. Configure one service to own that shortcut. **Hold-Space Voice** is available for applications accepting a down/up hold; its handle detection follows sound and can release during silence. **Command Voice** supplies editable slash-command examples. **Blank** starts empty.

Actions: None, Hold Key, Keystroke, Shortcut and Type Text. Hold Key releases on the inferred handle release or sample ending. Text is one line with optional delayed Enter, disabled by default in starters. The bridge never executes shell commands. Ordinary actions target the armed app; explicit system shortcuts enter the macOS event stream.

Profile JSON schema 2 is exported; schema 1 remains importable. Imports are validated and added as new copies, never silently overwriting an existing profile. They cannot arm output, select an input or write mic files. The example JSON files in [profiles/](../profiles/) are generated from the same Swift templates used in the app.

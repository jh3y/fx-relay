# FX Relay — visual identity

**FX Relay** is the chosen product name: the microphone provides a physical signal, and the utility relays it as a configurable action. It was previously called FX-MIC Bridge. The source repository is [jh3y/fx-relay](https://github.com/jh3y/fx-relay).

The direction is a small instrument panel: warm neutral surfaces, charcoal, a restrained orange accent, monospaced labels, numbered banks and clear physical controls. The v0.7 icon uses a graphite tile, cream mic silhouette, orange trigger/output port and four recessed bank indicators. The smallest size omits detail to preserve the silhouette. Light/dark appearance follows macOS. Avoid copying Teenage Engineering's logo or implying official affiliation.

Original assets:

- [App icon SVG](brand/icon.svg), plus the native multi-size `.icns` in Resources.
- [README header](brand/hero.svg).
- [Wordmark](brand/wordmark.svg).
- The menu-bar template mark stays recognizable while its status indicator changes.

`script/generate_brand.py` produces the editable vector assets. `script/generate_icon.swift` produces the icon sizes. No stock images, remote fonts or generated raster logo are required.

The original name shortlist also included Cuegrip and CUE/16. FX Relay was chosen for clarity.

Optional Krea brief: “A small native macOS utility for a handheld microphone used as a programmable controller. Warm off-white, charcoal and one orange accent. Geometric mic/handle and a single physical button. Precise monospaced typography, four understated bank indicators. Simple enough to work at 16 pixels. Original identity; no manufacturer logos, gradients of rainbow color, robot mascots or waveform-heavy AI branding.”

Krea is optional concept exploration; the shipping icon remains editable vector/code artwork. Useful variations would explore (1) a mic and relay contact, (2) a compact four-bank instrument panel, and (3) a minimal handle/trigger silhouette. Keep the same restricted palette, ask for flat front views on plain backgrounds, and compare the silhouettes at small sizes before choosing details. Translate the selected direction into native icon assets rather than using a screenshot of a mockup.

## Copyable Krea prompt

> Design three distinct visual concepts for **FX Relay**, a native macOS menu-bar utility that turns a handheld microphone into a programmable controller. Think compact musical instrument, precise industrial design and Teenage Engineering-inspired restraint. Give it an original identity without manufacturer logos or borrowed product graphics.
>
> Use warm off-white, graphite and one vivid orange accent. Explore a geometric microphone/trigger, a relay contact and four numbered bank indicators. Precise monospaced labels, strong spacing and tactile details should make it feel like a useful little instrument. Avoid robot mascots, AI sparkle symbols, decorative waveforms and rainbow gradients.
>
> For each concept, show a 1024 × 1024 macOS app-icon design, a separate monochrome menu-bar symbol legible at 16–18 pixels, and a flat, front-facing 380-pixel-wide popover mockup in light and dark mode. The popover needs a profile selector, current bank, handle mapping, four sample-action rows, a compact input meter, one Pause control and a Setup link. Example mappings: Hold Space, Enter, /voice, Control+C, Unassigned. Prioritize readable hierarchy and comfortable click targets. Keep native macOS pickers, buttons and toggles recognizable. Put detailed editing in a separate window; this is a compact desktop utility, not a mobile dashboard.
>
> Present the concepts on plain backgrounds without perspective, laptop renders or marketing copy. Include small-size icon previews so we can judge the silhouette. These are art-direction references for a SwiftUI implementation, not final interface screenshots.

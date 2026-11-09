# FX Relay — Contact identity

The Contact identity uses two terminals and an open orange arm, reflecting the bridge between a physical microphone and a configurable action. It is an original relay symbol, with no manufacturer marks or implied affiliation.

Light mode uses warm off-white (`#F5F3EC`); dark mode uses graphite (`#292B28`). Orange (`#FF5A1F`) highlights selection and activity. System typography and controls remain native; monospaced type is reserved for bank numbers, shortcuts and measurements. Native material appears once at the window surface, with solid control wells. Reduce Transparency and Increase Contrast switch to solid surfaces.

- [App icon](brand/icon.svg): original vector artwork rendered at each native icon size, with transparent outer margins. The concept-study background and shadow are not included.
- [Menu symbol](brand/contact-symbol.svg): a separate monochrome drawing. Runtime state changes the contact rather than adding another status dot.
- [README header](brand/hero.svg) and [wordmark](brand/wordmark.svg).

The Swift renderer in `script/generate_icon.swift` produces the `.iconset`; `iconutil` packages it as `.icns`. `script/generate_brand.py` produces editable SVG assets. No remote fonts, new design framework or generated raster logo are needed at runtime.

#!/usr/bin/env python3
"""Original Contact vector assets; no presentation backgrounds baked into the app icon."""
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
out = ROOT / 'docs' / 'brand'
out.mkdir(parents=True, exist_ok=True)
art = '''<defs><linearGradient id="tile" x1="0" y1="1" x2="1" y2="0"><stop stop-color="#242724"/><stop offset="1" stop-color="#363b37"/></linearGradient>
<clipPath id="clip"><rect x="80" y="80" width="864" height="864" rx="190"/></clipPath></defs>
<g clip-path="url(#clip)"><rect x="80" y="80" width="864" height="864" fill="url(#tile)"/>
<g stroke="#f1ebd0" stroke-width="46" stroke-linecap="round"><path d="M80 674H310M714 350H944"/></g>
<path d="M310 674L615 413" stroke="#ff5a1f" stroke-width="58" stroke-linecap="round"/>
<g fill="#f1ebd0"><circle cx="310" cy="674" r="65"/><circle cx="714" cy="350" r="65"/></g></g>
<rect x="80" y="80" width="864" height="864" rx="190" fill="none" stroke="#fff" stroke-opacity=".2" stroke-width="2"/>'''
(out/'icon.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024" role="img" aria-label="FX Relay Contact icon">{art}</svg>\n')
(out/'contact-symbol.svg').write_text('''<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 16 16"><g fill="none" stroke="currentColor" stroke-width="1.65" stroke-linecap="round"><path d="M1 12h2m10-8h2M5.6 10.7l3.55-3.55"/><circle cx="4.5" cy="12" r="1.5"/><circle cx="11.5" cy="4" r="1.5"/></g></svg>\n''')
(out/'hero.svg').write_text(f'''<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="520" viewBox="0 0 1280 520" role="img" aria-labelledby="title desc">
<title id="title">FX Relay</title><desc id="desc">Native macOS control for the Teenage Engineering EP-2350 FX-MIC.</desc>
<rect width="1280" height="520" rx="20" fill="#f5f3ec"/>
<path d="M64 92H1216M64 432H1216" stroke="#292b28" stroke-opacity=".15"/>
<g fill="#292b28" font-family="-apple-system,BlinkMacSystemFont,Helvetica,Arial,sans-serif">
<text x="64" y="66" font-family="ui-monospace,Menlo,monospace" font-size="14" letter-spacing="1">EP–2350 → macOS</text>
<text x="60" y="242" font-size="92" font-weight="600" letter-spacing="-4">FX Relay</text>
<text x="66" y="300" font-size="23">Native macOS control for the FX-MIC.</text>
<text x="64" y="474" font-family="ui-monospace,Menlo,monospace" font-size="13">FOUR BANKS / SIXTEEN SAMPLES / EDITABLE PROFILES</text>
</g><g transform="translate(806 68) scale(.36)">{art}</g></svg>\n''')
(out/'wordmark.svg').write_text('''<svg xmlns="http://www.w3.org/2000/svg" width="440" height="100" viewBox="0 0 440 100" role="img" aria-label="FX Relay"><rect width="440" height="100" rx="12" fill="#f5f3ec"/><g transform="translate(22 22) scale(3.5)" stroke="#292b28" fill="none" stroke-width="1.65" stroke-linecap="round"><path d="M1 12h2m10-8h2"/><circle cx="4.5" cy="12" r="1.5"/><circle cx="11.5" cy="4" r="1.5"/><path d="M5.6 10.7l3.55-3.55" stroke="#ff5a1f"/></g><text x="108" y="66" font-family="-apple-system,Helvetica,Arial,sans-serif" font-size="44" font-weight="600" fill="#292b28">FX Relay</text></svg>\n''')
print('Wrote Contact brand SVGs')

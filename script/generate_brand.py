#!/usr/bin/env python3
"""Original vector brand assets. No remote fonts, photos or third-party artwork."""
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
out = ROOT / 'docs' / 'brand'
out.mkdir(parents=True, exist_ok=True)
mark = '''<g fill="#f0ede0"><rect x="272" y="206" width="324" height="404" rx="112"/>
<rect x="382" y="510" width="104" height="310" rx="34"/></g>
<rect x="522" y="622" width="64" height="156" rx="24" fill="#f74f1c"/>
<g fill="#1f2121">''' + ''.join(f'<rect x="334" y="{y}" width="200" height="22" rx="11"/>' for y in (290,354,418,482)) + '''</g>
<rect x="636" y="497" width="110" height="20" rx="10" fill="#6b6e69"/>
<circle cx="752" cy="507" r="58" fill="#f74f1c"/>
<g>''' + ''.join(f'<rect x="653" y="{752-i*33}" width="20" height="12" rx="5" fill="{("#f74f1c" if i == 3 else "#575954")}"/>' for i in range(4)) + '</g>'
icon = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024" role="img" aria-label="FX Relay icon">
<rect x="58" y="58" width="908" height="908" rx="196" fill="#1f2121" stroke="#494b49" stroke-width="3"/>{mark}</svg>'''
(out/'icon.svg').write_text(icon+'\n')
hero=f'''<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="600" viewBox="0 0 1280 600" role="img" aria-labelledby="title desc">
<title id="title">FX Relay</title><desc id="desc">Physical controls. Programmable actions. A native macOS controller for the EP-2350.</desc>
<rect width="1280" height="600" rx="24" fill="#ece9df"/>
<g stroke="#292d2d" stroke-opacity=".09"><path d="M64 92H1216M64 506H1216M800 92V506"/></g>
<g font-family="ui-monospace, SFMono-Regular, Menlo, monospace" fill="#292d2d">
<text x="64" y="62" font-size="13" letter-spacing="2">FX–MIC / CONTROL UTILITY</text>
<text x="1216" y="62" text-anchor="end" font-size="13" letter-spacing="2">macOS · EP–2350</text>
<text x="58" y="223" font-size="99" font-weight="700" letter-spacing="-6">FX</text>
<text x="58" y="328" font-size="99" font-weight="700" letter-spacing="-6">RELAY<tspan fill="#f24b1a">.</tspan></text>
<text x="64" y="392" font-size="24">Physical controls.</text><text x="64" y="428" font-size="24">Programmable actions.</text>
<text x="64" y="548" font-size="12" letter-spacing="1.5">FOUR BANKS / SIXTEEN MAPPINGS / YOUR WORKFLOW</text>
<text x="1216" y="548" text-anchor="end" font-size="12" letter-spacing="1.5">AUDIO → ACTION</text>
</g>
<g transform="translate(789 96) scale(.40)"><rect width="1024" height="1024" rx="200" fill="#1f2121"/>{mark}</g>
</svg>'''
(out/'hero.svg').write_text(hero+'\n')
(out/'wordmark.svg').write_text('''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 100" role="img" aria-label="FX Relay"><rect width="600" height="100" rx="16" fill="#ece9df"/><text x="24" y="64" font-family="ui-monospace,Menlo,monospace" font-size="44" font-weight="700" fill="#292d2d">FX RELAY</text><circle cx="570" cy="50" r="9" fill="#f24b1a"/></svg>\n''')
print('Wrote docs/brand/{icon,hero,wordmark}.svg')

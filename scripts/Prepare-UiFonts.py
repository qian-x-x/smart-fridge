"""Build OFL-licensed local fonts for common Chinese UI and seeded recipe text.

Usage: python scripts/Prepare-UiFonts.py --cache-dir <a writable cache directory>
Requires fontTools. The upstream license is retained beside the derived fonts.
"""
from argparse import ArgumentParser
from pathlib import Path
import hashlib
import json
from urllib.request import urlopen
from fontTools.ttLib import TTFont
from fontTools import subset
from fontTools.varLib.instancer import instantiateVariableFont

parser = ArgumentParser()
parser.add_argument('--cache-dir', required=True, type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
cache = args.cache_dir.resolve()
cache.mkdir(parents=True, exist_ok=True)
target = root / 'apps/fridge-app/assets/fonts'
target.mkdir(parents=True, exist_ok=True)
base = 'https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/'
font_url = base + 'NotoSansSC%5Bwght%5D.ttf'
original = cache / 'NotoSansSC-variable.ttf'
if not original.exists():
    with urlopen(font_url, timeout=60) as response:
        original.write_bytes(response.read())
with urlopen(base + 'OFL.txt', timeout=30) as response:
    (target / 'OFL.txt').write_bytes(response.read())

# GB2312 covers common Simplified Chinese names and daily ingredient vocabulary.
# Also retain every character currently used by the UI and seeded recipe data.
characters = {chr(code) for code in range(0x20, 0x100)}
characters.update(chr(code) for code in range(0x2000, 0x2070))
characters.update(chr(code) for code in range(0x3000, 0x3040))
characters.update(chr(code) for code in range(0xFF00, 0xFFF0))
for first in range(0xA1, 0xF8):
    for second in range(0xA1, 0xFF):
        try:
            characters.update(bytes([first, second]).decode('gb2312'))
        except UnicodeDecodeError:
            pass
for folder in [root / 'apps/fridge-app/lib', root / 'backend/recipe-service/src/main/resources']:
    for file in folder.rglob('*'):
        if file.suffix in {'.dart', '.sql'}:
            characters.update(file.read_text(encoding='utf-8'))

manifest = {'source': font_url, 'license': base + 'OFL.txt', 'sourceSha256': hashlib.sha256(original.read_bytes()).hexdigest(), 'family': 'Xiaoyi UI', 'coverage': 'GB2312 + current UI and seeded recipe text', 'files': []}
for weight, name in [(400, 'Regular'), (600, 'Semibold')]:
    font = TTFont(original)
    options = subset.Options()
    options.name_IDs = ['*']
    options.name_legacy = True
    options.name_languages = ['*']
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(unicodes={ord(char) for char in characters})
    subsetter.subset(font)
    font = instantiateVariableFont(font, {'wght': weight}, inplace=True)
    for record in font['name'].names:
        if record.nameID in {1, 2, 3, 4, 6, 16, 17}:
            value = {1: 'Xiaoyi UI', 2: name, 3: f'XiaoyiUI-{name}', 4: f'Xiaoyi UI {name}', 6: f'XiaoyiUI-{name}', 16: 'Xiaoyi UI', 17: name}[record.nameID]
            record.string = value.encode(record.getEncoding())
    file = target / f'XiaoyiUI-{name}.ttf'
    font.save(file)
    manifest['files'].append({'name': file.name, 'weight': weight, 'bytes': file.stat().st_size})
    print(f'{file.name}: {file.stat().st_size} bytes')
(target / 'provenance.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

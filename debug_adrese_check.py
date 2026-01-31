#!/usr/bin/env python3
"""DEBUG adrese table check"""
import re
from pathlib import Path

table = 'adrese'
pattern = rf"\.from\('{table}'\).*?(?:insert|upsert|update)\s*\(\s*\{{([^}}]*?)\}}"

print(f"Pattern: {pattern}")
print()

for f in Path('lib').rglob('*.dart'):
    content = f.read_text(errors='ignore')
    for m in re.finditer(pattern, content, re.DOTALL):
        print(f'File: {f}')
        print(f'Match: {m.group(0)[:300]}...')
        cols = re.findall(r"'([a-z_]\w*)':", m.group(1))
        print(f'Columns: {cols}')
        print('---')
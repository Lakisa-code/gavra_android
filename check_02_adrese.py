#!/usr/bin/env python3
"""CHECK TABLE 02: adrese"""
import re
from pathlib import Path

table = 'adrese'
expected = ['id', 'naziv', 'grad', 'ulica', 'broj', 'koordinate']
jsonb_fields = ['koordinate']

pattern = rf"\.from\('{table}'\).*?(?:insert|upsert|update)\s*\(\s*\{{([^}}]*?)\}}"
found = []

for f in Path('lib').rglob('*.dart'):
    content = f.read_text(errors='ignore')
    clean = content
    for jf in jsonb_fields:
        clean = re.sub(rf"'{jf}':\s*\{{[^}}]*\}}", '', clean, flags=re.DOTALL)
    for m in re.finditer(pattern, clean, re.DOTALL):
        cols = re.findall(r"'([a-z_]\w*)':", m.group(1))
        found.extend(cols)

found = set(found)
expected_set = set(expected)
problems = found - expected_set

print(f"\n{'='*60}")
print(f"TABLE: {table}")
print(f"{'='*60}")
print(f"Expected: {expected}")
print(f"Found in code: {sorted(found)}")
if problems:
    print(f"❌ PROBLEMS: {sorted(problems)}")
else:
    print(f"✅ OK")

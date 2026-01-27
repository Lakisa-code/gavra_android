import re

path = r'c:\Users\Bojan\gavra_android\lib\screens\registrovani_putnik_profil_screen.dart'

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. withValues(alpha: X) -> withOpacity(X)
content = content.replace('.withValues(alpha: ', '.withOpacity(')

# 2. Fix nested interpolation at line 1276 (approximately)
# 'KIŠA ${data.precipitationStartTime ?? 'SADA'}${data.precipitationProbability != null ? ' (${data.precipitationProbability}%)' : ''}'
# Change to a more standard way if needed, but formatting might have changed the line.
# Actually let's just target the pattern.
content = content.replace("' (${data.precipitationProbability}%)'", '" (${data.precipitationProbability}%)"')

# 3. Replace ✓ with OK
content = content.replace('✓', 'OK')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done.")

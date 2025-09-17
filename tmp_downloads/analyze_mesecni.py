import csv
from collections import defaultdict

INPUT = 'tmp_downloads/mesecni_putnici_rows.csv'
DAYS = ['pon', 'uto', 'sre', 'cet', 'pet']

def normalize_time(t):
    if not t:
        return ''
    t = t.strip()
    if not t:
        return ''
    # remove fractional seconds if any and timezone
    if ' ' in t:
        t = t.split(' ')[0]
    parts = t.split(':')
    if len(parts) >= 2:
        hh = parts[0].lstrip('0') or '0'
        mm = parts[1]
        return f"{int(hh)}:{mm}"
    return t


def analyze():
    per_day = {d: {'rows': 0, 'bc': 0, 'vs': 0, 'bc_times': defaultdict(int), 'vs_times': defaultdict(int)} for d in DAYS}

    try:
        f = open(INPUT, newline='', encoding='utf-8')
    except FileNotFoundError:
        print(f"File not found: {INPUT}")
        return
    with f:
        reader = csv.DictReader(f)
        for row in reader:
            radni = row.get('radni_dani', '') or ''
            for d in DAYS:
                if d in radni:
                    per_day[d]['rows'] += 1
                    # BC per-day column name
                    bc_col = f'polazak_bc_{d}'
                    vs_col = f'polazak_vs_{d}'
                    bc_val = row.get(bc_col, '') or ''
                    vs_val = row.get(vs_col, '') or ''
                    # fallback to legacy columns
                    legacy_bc = row.get('polazak_bela_crkva', '') or ''
                    legacy_vs = row.get('polazak_vrsac', '') or ''
                    # choose bc time
                    bc_time = normalize_time(bc_val) if bc_val.strip() else normalize_time(legacy_bc)
                    vs_time = normalize_time(vs_val) if vs_val.strip() else normalize_time(legacy_vs)
                    if bc_time:
                        per_day[d]['bc'] += 1
                        per_day[d]['bc_times'][bc_time] += 1
                    if vs_time:
                        per_day[d]['vs'] += 1
                        per_day[d]['vs_times'][vs_time] += 1

    # print summary
    for d in DAYS:
        stats = per_day[d]
        print(f"Day: {d}")
        print(f"  Matching rows (radni_dani contains): {stats['rows']}")
        print(f"  BC departures: {stats['bc']}")
        print(f"  VS departures: {stats['vs']}")
        print(f"  BC times (most common):")
        for t, c in sorted(stats['bc_times'].items(), key=lambda x: (-x[1], x[0]))[:10]:
            print(f"    {t}: {c}")
        print(f"  VS times (most common):")
        for t, c in sorted(stats['vs_times'].items(), key=lambda x: (-x[1], x[0]))[:10]:
            print(f"    {t}: {c}")
        print()

if __name__ == '__main__':
    analyze()

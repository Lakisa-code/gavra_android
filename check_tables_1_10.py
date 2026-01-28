#!/usr/bin/env python3
"""
AUTOMATED 30-TABLE CHECKER - SIMPLE VERSION
"""

import re
from pathlib import Path

def check_table_direct(table_name, expected_cols, jsonb_fields=None):
    """Direktno pronađi insert/update blokove za tabelu"""
    if jsonb_fields is None:
        jsonb_fields = []
    
    found_cols = set()
    
    # Pattern: .from('table').insert({ ... })  ili  .from('table').update({ ... })
    # Trebam SAMO sadržaj između { }
    
    for dart_file in Path('lib').rglob('*.dart'):
        try:
            content = dart_file.read_text(errors='ignore')
            
            # Pronađi sve .from('table_name').insert/update/upsert
            # Važno: tražimo samo ODMAH posle .from('table')
            pattern = rf"\.from\s*\(\s*['\"]({table_name})['\"].*?\.(insert|upsert|update)\s*\(\s*\{{([^}}]+)\}}"
            
            for match in re.finditer(pattern, content, re.DOTALL):
                block = match.group(3)  # Sadržaj između { }
                
                # Ukloni JSONB polja
                for jf in jsonb_fields:
                    block = re.sub(rf"['\"]?{jf}['\"]?\s*:\s*\{{[^}}]*\}}", '', block, flags=re.DOTALL)
                
                # Pronađi sve 'kolona':
                for col_match in re.finditer(r"['\"]([a-z_]\w*)['\"]:\s*", block):
                    col_name = col_match.group(1)
                    found_cols.add(col_name)
        except:
            pass
    
    expected = set(expected_cols)
    problems = found_cols - expected
    
    return {
        'table': table_name,
        'expected': expected_cols,
        'found': sorted(found_cols),
        'problems': sorted(problems),
        'ok': len(problems) == 0
    }

# ============================================================================
# Sve tabele
# ============================================================================

TABLES = [
    ('admin_audit_logs', ['id', 'created_at', 'admin_name', 'action_type', 'details', 'metadata'], ['metadata']),
    ('adrese', ['id', 'naziv', 'grad', 'ulica', 'broj', 'koordinate'], ['koordinate']),
    ('app_config', ['key', 'value', 'description', 'updated_at'], []),
    ('app_settings', ['id', 'updated_at', 'updated_by', 'nav_bar_type', 'dnevni_zakazivanje_aktivno', 'min_version', 'latest_version', 'store_url_android', 'store_url_huawei'], []),
    ('daily_reports', ['id', 'vozac', 'datum', 'ukupan_pazar', 'sitan_novac', 'checkin_vreme', 'otkazani_putnici', 'naplaceni_putnici', 'pokupljeni_putnici', 'dugovi_putnici', 'mesecne_karte', 'kilometraza', 'automatski_generisan', 'created_at', 'vozac_id'], []),
    ('finansije_licno', ['id', 'created_at', 'tip', 'naziv', 'iznos'], []),
    ('finansije_troskovi', ['id', 'naziv', 'tip', 'iznos', 'mesecno', 'aktivan', 'vozac_id', 'created_at', 'updated_at', 'mesec', 'godina'], []),
    ('fuel_logs', ['id', 'created_at', 'type', 'liters', 'price', 'amount', 'vozilo_uuid', 'km', 'pump_meter', 'metadata'], ['metadata']),
    ('kapacitet_polazaka', ['id', 'grad', 'vreme', 'max_mesta', 'aktivan', 'napomena'], []),
    ('ml_config', ['id', 'data', 'config', 'updated_at'], ['data', 'config']),
]

if __name__ == '__main__':
    print("\n🚀 PROVERA 10 TABELA (PRVI DEO)\n")
    print("="*70)
    
    results = []
    for table_info in TABLES:
        table_name = table_info[0]
        cols = table_info[1]
        jsonb = table_info[2] if len(table_info) > 2 else []
        result = check_table_direct(table_name, cols, jsonb)
        results.append(result)
        
        status = "✅" if result['ok'] else "❌"
        print(f"\n{status} {result['table']}")
        if result['found']:
            print(f"   Found: {result['found']}")
        if result['problems']:
            print(f"   Problems: {result['problems']}")
    
    print(f"\n{'='*70}\n")
    ok_count = sum(1 for r in results if r['ok'])
    print(f"Rezultat: {ok_count}/{len(results)} OK\n")

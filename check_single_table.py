#!/usr/bin/env python3
"""
🔍 SIMPLE SCHEMA CHECKER - Tabela po tabela
Provera jedne tabele odjednom
"""

import re
from pathlib import Path
from collections import defaultdict

def check_table(table_name: str, expected_columns: list) -> dict:
    """Proveri jednu tabelu"""
    print(f"\n{'='*70}")
    print(f"📊 PROVERAVA SE: {table_name}")
    print(f"{'='*70}")
    print(f"Očekivane kolone: {expected_columns}\n")
    
    used_columns = defaultdict(list)
    problems = []
    
    lib_path = Path('lib')
    
    # Pronađi sve .from('table_name').insert/update
    pattern = rf"\.from\('{table_name}'\)\s*\.\s*(?:insert|upsert|update)\s*\(\s*\{{([^}}]+?)\}}"
    
    for dart_file in lib_path.rglob('*.dart'):
        try:
            content = dart_file.read_text(encoding='utf-8', errors='ignore')
            
            for match in re.finditer(pattern, content, re.DOTALL):
                insert_block = match.group(1)
                
                # Ekstraktuj kolone: 'kolona': vrednost
                col_pattern = r"'([a-z_]\w*)':\s*"
                
                for col_match in re.finditer(col_pattern, insert_block):
                    column = col_match.group(1)
                    if column not in used_columns[dart_file.name]:
                        used_columns[dart_file.name].append(column)
        except:
            pass
    
    # Analiza
    all_used = set()
    for file_cols in used_columns.values():
        all_used.update(file_cols)
    
    if all_used:
        print(f"✅ Pronađene korišćene kolone u kodu: {sorted(all_used)}\n")
        
        # Pronađi probleme
        unknown = all_used - set(expected_columns)
        
        if unknown:
            print(f"❌ PROBLEME PRONAĐENO:\n")
            for col in sorted(unknown):
                print(f"   ❌ '{col}' - NE POSTOJI U BAZI!")
                problems.append(col)
                
                # Pronađi fajl gde se koristi
                for file_name, cols in used_columns.items():
                    if col in cols:
                        print(f"      📄 Koristi se u: {file_name}")
        else:
            print(f"✅ SVE KOLONE SU OK!")
            print(f"   - Sve {len(all_used)} korišćene kolone postoje u bazi")
    else:
        print(f"⚠️  Nije pronađena korišćenja ove tabele u kodu")
    
    return {
        'table': table_name,
        'expected': expected_columns,
        'used': all_used,
        'problems': problems,
        'ok': len(problems) == 0
    }

# ============================================================================
# MAIN - POČNIMO SA TESTIRANIM TABELAMA
# ============================================================================

if __name__ == '__main__':
    print("\n🚀 CHECKER PO TABELAMA - Krenimo sa FUEL_LOGS (već ispravljena)\n")
    
    # Tabela koju smo sigurno ispravili
    fuel_logs_result = check_table(
        'fuel_logs',
        ['id', 'created_at', 'type', 'liters', 'price', 'amount', 
         'vozilo_uuid', 'km', 'pump_meter', 'metadata']
    )
    
    print(f"\n{'='*70}")
    if fuel_logs_result['ok']:
        print(f"✅ REZULTAT: fuel_logs - SVE JE U REDU!")
    else:
        print(f"❌ REZULTAT: fuel_logs - PROBLEME: {fuel_logs_result['problems']}")
    print(f"{'='*70}\n")

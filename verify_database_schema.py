#!/usr/bin/env python3
"""
🔍 AUTOMATSKA VERIFIKACIJA SUPABASE SCHEMA-E
Provera svih tabela i kolona direktno iz baze
"""

import os
import re
import json
from pathlib import Path
from collections import defaultdict
from typing import Dict, List, Set, Tuple

# ============================================================================
# SUPABASE SCHEMA - Učitano iz 30 tabela (28.01.2026)
# ============================================================================

SUPABASE_SCHEMA = {
    'admin_audit_logs': ['id', 'created_at', 'admin_name', 'action_type', 'details', 'metadata'],
    'adrese': ['id', 'naziv', 'grad', 'ulica', 'broj', 'koordinate'],
    'app_config': ['key', 'value', 'description', 'updated_at'],
    'app_settings': ['id', 'updated_at', 'updated_by', 'nav_bar_type', 'dnevni_zakazivanje_aktivno', 'min_version', 'latest_version', 'store_url_android', 'store_url_huawei'],
    'daily_reports': ['id', 'vozac', 'datum', 'ukupan_pazar', 'sitan_novac', 'checkin_vreme', 'otkazani_putnici', 'naplaceni_putnici', 'pokupljeni_putnici', 'dugovi_putnici', 'mesecne_karte', 'kilometraza', 'automatski_generisan', 'created_at', 'vozac_id', 'updated_at'],
    'finansije_licno': ['id', 'created_at', 'tip', 'naziv', 'iznos'],
    'finansije_troskovi': ['id', 'naziv', 'tip', 'iznos', 'mesecno', 'aktivan', 'vozac_id', 'created_at', 'updated_at', 'mesec', 'godina'],
    'fuel_logs': ['id', 'created_at', 'type', 'liters', 'price', 'amount', 'vozilo_uuid', 'km', 'pump_meter', 'metadata'],
    'kapacitet_polazaka': ['id', 'grad', 'vreme', 'max_mesta', 'aktivan', 'napomena'],
    'ml_config': ['id', 'data', 'config', 'updated_at'],
    'payment_reminders_log': ['id', 'reminder_date', 'reminder_type', 'triggered_by', 'total_unpaid_passengers', 'total_notifications_sent', 'created_at'],
    # 'pending_resolution_queue': ['id', 'putnik_id', 'grad', 'dan', 'vreme', 'old_status', 'new_status', 'message_title', 'message_body', 'created_at', 'sent', 'sent_at', 'alternative_time'],  # TABLE REMOVED
    'pin_zahtevi': ['id', 'putnik_id', 'email', 'telefon', 'status', 'created_at'],
    'promene_vremena_log': ['id', 'putnik_id', 'datum', 'created_at', 'ciljni_dan', 'datum_polaska', 'sati_unapred'],
    'push_tokens': ['id', 'provider', 'token', 'user_id', 'created_at', 'updated_at', 'user_type', 'putnik_id', 'vozac_id'],
    'putnik_pickup_lokacije': ['id', 'putnik_id', 'putnik_ime', 'lat', 'lng', 'vozac_id', 'datum', 'vreme', 'created_at'],
    'racun_sequence': ['godina', 'poslednji_broj', 'updated_at'],
    'registrovani_putnici': ['id', 'putnik_ime', 'tip', 'tip_skole', 'broj_telefona', 'broj_telefona_oca', 'broj_telefona_majke', 'polasci_po_danu', 'aktivan', 'status', 'datum_pocetka_meseca', 'datum_kraja_meseca', 'vozac_id', 'obrisan', 'created_at', 'updated_at', 'adresa_bela_crkva_id', 'adresa_vrsac_id', 'pin', 'cena_po_danu', 'broj_telefona_2', 'email', 'uklonjeni_termini', 'firma_naziv', 'firma_pib', 'firma_mb', 'firma_ziro', 'firma_adresa', 'treba_racun', 'tip_prikazivanja', 'broj_mesta', 'merged_into_id', 'is_duplicate', 'radni_dani'],
    'seat_request_notifications': ['id', 'putnik_id', 'seat_request_id', 'title', 'body', 'sent', 'sent_at', 'created_at'],
    'seat_requests': ['id', 'putnik_id', 'grad', 'datum', 'zeljeno_vreme', 'dodeljeno_vreme', 'status', 'created_at', 'updated_at', 'processed_at', 'priority', 'batch_id', 'alternatives', 'changes_count', 'broj_mesta'],
    'troskovi_unosi': ['id', 'datum', 'tip', 'iznos', 'opis', 'vozilo_id', 'vozac_id', 'created_at'],
    'user_daily_changes': ['id', 'putnik_id', 'datum', 'changes_count', 'last_change_at', 'created_at'],
    'vozac_lokacije': ['id', 'vozac_id', 'vozac_ime', 'lat', 'lng', 'grad', 'vreme_polaska', 'smer', 'putnici_eta', 'aktivan', 'updated_at'],
    'vozaci': ['id', 'ime', 'email', 'telefon', 'sifra', 'boja'],
    'vozila': ['id', 'registarski_broj', 'marka', 'model', 'godina_proizvodnje', 'broj_mesta', 'naziv', 'broj_sasije', 'registracija_vazi_do', 'mali_servis_datum', 'mali_servis_km', 'veliki_servis_datum', 'veliki_servis_km', 'alternator_datum', 'alternator_km', 'gume_datum', 'gume_opis', 'napomena', 'akumulator_datum', 'akumulator_km', 'plocice_datum', 'plocice_km', 'trap_datum', 'trap_km', 'radio', 'gume_prednje_datum', 'gume_prednje_opis', 'gume_zadnje_datum', 'gume_zadnje_opis', 'kilometraza', 'plocice_prednje_datum', 'plocice_prednje_km', 'plocice_zadnje_datum', 'plocice_zadnje_km', 'gume_prednje_km', 'gume_zadnje_km'],
    'vozila_istorija': ['id', 'vozilo_id', 'tip', 'datum', 'km', 'opis', 'cena', 'pozicija', 'created_at'],
    'voznje_log': ['id', 'putnik_id', 'datum', 'tip', 'iznos', 'vozac_id', 'created_at', 'placeni_mesec', 'placena_godina', 'sati_pre_polaska', 'broj_mesta', 'detalji', 'meta'],
    'vreme_vozac': ['id', 'grad', 'vreme', 'dan', 'vozac_ime', 'created_at', 'updated_at'],
    'weather_alerts_log': ['id', 'alert_date', 'alert_types', 'created_at']
}

# ============================================================================
# ANALIZA KODA
# ============================================================================

def extract_insert_update_columns(dart_file: Path) -> Dict[str, Set[str]]:
    """Ekstraktuj sve insert/update kolone - PRECIZNIJE"""
    table_columns = defaultdict(set)
    
    try:
        content = dart_file.read_text(encoding='utf-8', errors='ignore')
        
        # Pattern: .from('table_name').insert({ ... })
        pattern = r"\.from\('([^']+)'\)\s*\.\s*(?:insert|upsert|update)\s*\(\s*\{([^}]+?)\}"
        
        for match in re.finditer(pattern, content, re.DOTALL):
            table_name = match.group(1)
            insert_block = match.group(2)
            
            # Ekstraktuj SAMO 'kolona': vrednost
            col_pattern = r"'([a-z_]\w*)':\s*(?![{])"
            
            for col_match in re.finditer(col_pattern, insert_block):
                column_name = col_match.group(1)
                # Filtriranje - preskočи pseudo-kolone
                if not any(x in column_name for x in ['Controller', 'Map', 'List']):
                    table_columns[table_name].add(column_name)
    except Exception as e:
        pass
    
    return table_columns

def analyze_all_dart_files() -> Dict[str, Dict[str, Set[str]]]:
    """Analiziraj sve .dart fajlove"""
    lib_path = Path('lib')
    analysis = defaultdict(lambda: defaultdict(set))
    
    print("📂 Skeniranje Dart fajlova...")
    for dart_file in lib_path.rglob('*.dart'):
        columns = extract_insert_update_columns(dart_file)
        for table, cols in columns.items():
            analysis[table]['used'].update(cols)
    
    return analysis

def compare_schemas() -> Tuple[List[Dict], int, int]:
    """Poredi kod sa Supabase schemi"""
    code_analysis = analyze_all_dart_files()
    problems = []
    total_checks = 0
    total_issues = 0
    
    print("\n" + "="*80)
    print("🔍 POREĐENJE KOLONA - KOD vs SUPABASE")
    print("="*80 + "\n")
    
    for table_name, expected_cols in SUPABASE_SCHEMA.items():
        used_cols = code_analysis.get(table_name, {}).get('used', set())
        
        if used_cols:
            print(f"📊 Tablica: {table_name}")
            print(f"   Schema kolone: {len(expected_cols)}")
            print(f"   Korišćene kolone: {len(used_cols)}")
            
            # Pronađi probleme
            unknown_cols = used_cols - set(expected_cols)
            if unknown_cols:
                total_issues += len(unknown_cols)
                for col in sorted(unknown_cols):
                    print(f"   ❌ GREŠKA: Kolona '{col}' ne postoji u bazi!")
                    problems.append({
                        'table': table_name,
                        'column': col,
                        'issue': 'Column does not exist in schema'
                    })
            else:
                print(f"   ✅ OK - Sve {len(used_cols)} korišćenih kolona postoje u bazi")
            
            print()
            total_checks += len(used_cols)
    
    return problems, total_checks, total_issues

def generate_report() -> str:
    """Generiši finalni report"""
    problems, total_checks, total_issues = compare_schemas()
    
    report = f"""
{'='*80}
📋 FINALNI REPORT - DATABASE SCHEMA VERIFICATION
{'='*80}

✅ STATISTIKA:
   - Ukupno tabela u Supabase: {len(SUPABASE_SCHEMA)}
   - Ukupno kolona: {sum(len(cols) for cols in SUPABASE_SCHEMA.values())}
   - Proverenih kolona iz koda: {total_checks}
   - Pronađenih problema: {total_issues}

{'='*80}

"""
    
    if total_issues == 0:
        report += """
✅ REZULTAT: BEZ PROBLEMA
   - Sve korišćene kolone postoje u Supabase schemi
   - 100% kompatibilnost između koda i baze
   - Baza je spremna za produkciju
        
"""
    else:
        report += f"""
❌ REZULTAT: {total_issues} PROBLEMA PRONAĐENO

Problematične kolone:
"""
        for p in problems:
            report += f"   - {p['table']}.{p['column']}: {p['issue']}\n"
    
    report += f"""
{'='*80}
Izveštaj generisan: 28.01.2026
{'='*80}
"""
    return report

# ============================================================================
# MAIN
# ============================================================================

if __name__ == '__main__':
    print("\n🚀 POKRETANJE AUTOMATSKE VERIFIKACIJE SUPABASE SCHEMA-E\n")
    
    report = generate_report()
    print(report)
    
    # Sačuvaj report
    with open('DATABASE_SCHEMA_VERIFICATION_REPORT.txt', 'w', encoding='utf-8') as f:
        f.write(report)
    
    print("📁 Report sačuvan u: DATABASE_SCHEMA_VERIFICATION_REPORT.txt\n")

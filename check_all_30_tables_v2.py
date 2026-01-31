#!/usr/bin/env python3
"""
✅ SCHEMA CHECKER - SVE 30 TABELA - POBOLJŠANA
Ignoriše kolone unutar JSONB objekata
"""

import re
from pathlib import Path
from collections import defaultdict

def check_table(table_name: str, expected_columns: list, jsonb_fields: list = None) -> dict:
    """Proveri jednu tabelu - sa mogućnošću da ignoriše JSONB polja"""
    if jsonb_fields is None:
        jsonb_fields = []
    
    used_columns = defaultdict(list)
    problems = []
    
    lib_path = Path('lib')
    pattern = rf"\.from\('{table_name}'\)\s*\.\s*(?:insert|upsert|update)\s*\(\s*\{{([^}}]+?)\}}"
    
    for dart_file in lib_path.rglob('*.dart'):
        try:
            content = dart_file.read_text(encoding='utf-8', errors='ignore')
            for match in re.finditer(pattern, content, re.DOTALL):
                insert_block = match.group(1)
                
                # Ukloni JSONB polja iz parsiranja
                for jsonb_field in jsonb_fields:
                    # Ukloni '{...}' za svako JSONB polje
                    pattern_jsonb = rf"'{jsonb_field}':\s*\{{[^}}]*\}}"
                    insert_block = re.sub(pattern_jsonb, '', insert_block, flags=re.DOTALL)
                
                col_pattern = r"'([a-z_]\w*)':\s*"
                for col_match in re.finditer(col_pattern, insert_block):
                    column = col_match.group(1)
                    if column not in used_columns[dart_file.name]:
                        used_columns[dart_file.name].append(column)
        except:
            pass
    
    all_used = set()
    for file_cols in used_columns.values():
        all_used.update(file_cols)
    
    if all_used:
        unknown = all_used - set(expected_columns)
        if unknown:
            for col in unknown:
                problems.append(col)
            return {'table': table_name, 'status': 'ERR', 'problems': problems}
        else:
            return {'table': table_name, 'status': 'OK', 'problems': None}
    else:
        return {'table': table_name, 'status': 'NIJE_KORISCENA', 'problems': None, 'note': 'Nije korišćena u kodu'}

# ============================================================================
# SVE 30 TABELA - sa JSONB fields
# ============================================================================

TABLES = [
    ('admin_audit_logs', ['id', 'created_at', 'admin_name', 'action_type', 'details', 'metadata', 'inventory_liters', 'total_debt', 'severity'], ['metadata']),
    ('adrese', ['id', 'naziv', 'grad', 'ulica', 'broj', 'gps_lat', 'gps_lng', 'created_at', 'updated_at'], []),
    ('app_config', ['key', 'value', 'description', 'updated_at'], []),
    ('app_settings', ['id', 'updated_at', 'updated_by', 'nav_bar_type', 'dnevni_zakazivanje_aktivno', 'min_version', 'latest_version', 'store_url_android', 'store_url_huawei'], []),
    ('daily_reports', ['id', 'vozac', 'datum', 'ukupan_pazar', 'sitan_novac', 'checkin_vreme', 'otkazani_putnici', 'naplaceni_putnici', 'pokupljeni_putnici', 'dugovi_putnici', 'mesecne_karte', 'kilometraza', 'automatski_generisan', 'created_at', 'vozac_id'], []),
    ('finansije_licno', ['id', 'created_at', 'tip', 'naziv', 'iznos'], []),
    ('finansije_troskovi', ['id', 'naziv', 'tip', 'iznos', 'mesecno', 'aktivan', 'vozac_id', 'created_at', 'updated_at', 'mesec', 'godina'], []),
    ('fuel_logs', ['id', 'created_at', 'type', 'liters', 'price', 'amount', 'vozilo_uuid', 'km', 'pump_meter', 'metadata'], ['metadata']),
    ('kapacitet_polazaka', ['id', 'grad', 'vreme', 'max_mesta', 'aktivan', 'napomena'], []),
    ('ml_config', ['id', 'data', 'config', 'updated_at'], ['data', 'config']),
    ('payment_reminders_log', ['id', 'reminder_date', 'reminder_type', 'triggered_by', 'total_unpaid_passengers', 'total_notifications_sent', 'created_at'], []),
    # ('pending_resolution_queue', ['id', 'putnik_id', 'grad', 'dan', 'vreme', 'old_status', 'new_status', 'message_title', 'message_body', 'created_at', 'sent', 'sent_at', 'alternative_time'], []),  # TABLE REMOVED
    ('pin_zahtevi', ['id', 'putnik_id', 'email', 'telefon', 'status', 'created_at'], []),
    ('promene_vremena_log', ['id', 'putnik_id', 'datum', 'created_at', 'ciljni_dan', 'datum_polaska', 'sati_unapred'], []),
    ('push_tokens', ['id', 'provider', 'token', 'user_id', 'created_at', 'updated_at', 'user_type', 'putnik_id', 'vozac_id'], []),
    ('putnik_pickup_lokacije', ['id', 'putnik_id', 'putnik_ime', 'lat', 'lng', 'vozac_id', 'datum', 'vreme', 'created_at'], []),
    ('racun_sequence', ['godina', 'poslednji_broj', 'updated_at'], []),
    ('registrovani_putnici', ['id', 'putnik_ime', 'tip', 'tip_skole', 'broj_telefona', 'broj_telefona_oca', 'broj_telefona_majke', 'polasci_po_danu', 'aktivan', 'status', 'datum_pocetka_meseca', 'datum_kraja_meseca', 'vozac_id', 'obrisan', 'created_at', 'updated_at', 'adresa_bela_crkva_id', 'adresa_vrsac_id', 'pin', 'cena_po_danu', 'broj_telefona_2', 'email', 'uklonjeni_termini', 'firma_naziv', 'firma_pib', 'firma_mb', 'firma_ziro', 'firma_adresa', 'treba_racun', 'tip_prikazivanja', 'broj_mesta', 'merged_into_id', 'is_duplicate', 'radni_dani'], ['polasci_po_danu', 'uklonjeni_termini']),
    ('seat_requests', ['id', 'putnik_id', 'grad', 'datum', 'zeljeno_vreme', 'dodeljeno_vreme', 'status', 'created_at', 'updated_at', 'processed_at', 'priority', 'batch_id', 'alternatives', 'changes_count', 'broj_mesta'], ['alternatives']),
    ('troskovi_unosi', ['id', 'datum', 'tip', 'iznos', 'opis', 'vozilo_id', 'vozac_id', 'created_at'], []),
    ('user_daily_changes', ['id', 'putnik_id', 'datum', 'changes_count', 'last_change_at', 'created_at'], []),
    ('vozac_lokacije', ['id', 'vozac_id', 'vozac_ime', 'lat', 'lng', 'grad', 'vreme_polaska', 'smer', 'putnici_eta', 'aktivan', 'updated_at'], ['putnici_eta']),
    ('vozaci', ['id', 'ime', 'email', 'telefon', 'sifra', 'boja'], []),
    ('vozila', ['id', 'registarski_broj', 'marka', 'model', 'godina_proizvodnje', 'broj_mesta', 'naziv', 'broj_sasije', 'registracija_vazi_do', 'mali_servis_datum', 'mali_servis_km', 'veliki_servis_datum', 'veliki_servis_km', 'alternator_datum', 'alternator_km', 'gume_datum', 'gume_opis', 'napomena', 'akumulator_datum', 'akumulator_km', 'plocice_datum', 'plocice_km', 'trap_datum', 'trap_km', 'radio', 'gume_prednje_datum', 'gume_prednje_opis', 'gume_zadnje_datum', 'gume_zadnje_opis', 'kilometraza', 'plocice_prednje_datum', 'plocice_prednje_km', 'plocice_zadnje_datum', 'plocice_zadnje_km', 'gume_prednje_km', 'gume_zadnje_km'], []),
    ('vozila_istorija', ['id', 'vozilo_id', 'tip', 'datum', 'km', 'opis', 'cena', 'pozicija', 'created_at'], []),
    ('voznje_log', ['id', 'putnik_id', 'datum', 'tip', 'iznos', 'vozac_id', 'created_at', 'placeni_mesec', 'placena_godina', 'sati_pre_polaska', 'broj_mesta', 'detalji', 'meta'], ['meta']),
    ('vreme_vozac', ['id', 'grad', 'vreme', 'dan', 'vozac_ime', 'created_at', 'updated_at'], []),
    ('weather_alerts_log', ['id', 'alert_date', 'alert_types', 'created_at'], [])
]

if __name__ == '__main__':
    print("\n*** PROVERA SVE 30 TABELA - POBOLJSANA ***\n")
    print("="*70)
    
    results = []
    for table_info in TABLES:
        if len(table_info) == 3:
            table_name, cols, jsonb = table_info
            result = check_table(table_name, cols, jsonb)
        else:
            result = check_table(table_info[0], table_info[1])
        results.append(result)
    
    print(f"\n{'='*70}")
    print("SAZETAK")
    print("="*70 + "\n")
    
    ok_count = 0
    problem_count = 0
    unused_count = 0
    
    for r in results:
        if r['status'] == 'OK':
            ok_count += 1
            print(f"OK {r['table']:<30} OK")
        elif r['status'] == 'NIJE_KORISCENA':
            unused_count += 1
            print(f"?? {r['table']:<30} NIJE KORISCENA")
        else:
            problem_count += 1
            print(f"ERR {r['table']:<30} PROBLEMI: {r['problems']}")
    
    print(f"\n{'='*70}")
    print(f"UKUPNO: {len(results)} tabela")
    print(f"  OK: {ok_count}")
    print(f"  ERR: {problem_count}")
    print(f"  ??: {unused_count}")
    print(f"{'='*70}\n")

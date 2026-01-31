#!/usr/bin/env python3
"""
🔍 ULTRA DETALJNA ANALIZA SVIH 30 SUPABASE TABELA
Datum: Januar 29, 2026
Verzija: Ultra Detailed Analysis v2.0
"""

import os
import json
import pandas as pd
from datetime import datetime, timedelta
from collections import defaultdict, Counter
from typing import Dict, List, Any, Tuple
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path

# Supabase konekcija
from supabase import create_client, Client

# Konfiguracija
SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_KEY = os.getenv('SUPABASE_ANON_KEY')

if not SUPABASE_URL or not SUPABASE_KEY:
    print("❌ SUPABASE_URL i SUPABASE_ANON_KEY moraju biti postavljeni!")
    exit(1)

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# Lista svih tabela
ALL_TABLES = [
    'admin_audit_logs', 'adrese', 'app_config', 'app_settings', 'daily_reports',
    'finansije_licno', 'finansije_troskovi', 'fuel_logs', 'kapacitet_polazaka',
    'ml_config', 'payment_reminders_log',  # 'pending_resolution_queue',  # TABLE REMOVED
    'pin_zahtevi',
    'promene_vremena_log', 'push_tokens', 'putnik_pickup_lokacije', 'racun_sequence',
    'registrovani_putnici', 'seat_requests',
    'troskovi_unosi', 'user_daily_changes', 'vozac_lokacije', 'vozaci', 'vozila',
    'vozila_istorija', 'voznje_log', 'voznje_log_with_names', 'vreme_vozac',
    'weather_alerts_log'
]

class UltraDetailedTableAnalyzer:
    """Ultra detaljna analiza jedne tabele"""

    def __init__(self, table_name: str):
        self.table_name = table_name
        self.data = None
        self.schema = None
        self.stats = {}
        self.issues = []
        self.recommendations = []

    def load_data(self) -> bool:
        """Učitaj sve podatke iz tabele"""
        try:
            print(f"📊 Učitavam podatke iz {self.table_name}...")

            # Prvo učitaj schema
            self.schema = self._get_table_schema()

            # Onda učitaj podatke
            response = supabase.table(self.table_name).select('*').execute()
            self.data = response.data

            print(f"✅ Učitano {len(self.data)} redova iz {self.table_name}")
            return True

        except Exception as e:
            print(f"❌ Greška pri učitavanju {self.table_name}: {e}")
            self.issues.append(f"Greška pri učitavanju: {str(e)}")
            return False

    def _get_table_schema(self) -> Dict:
        """Dohvati schema tabele"""
        try:
            # Koristimo information_schema za dobijanje schema
            query = f"""
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_name = '{self.table_name}'
            ORDER BY ordinal_position
            """
            result = supabase.rpc('execute_sql', {'query': query}).execute()
            return {row['column_name']: row for row in result.data}
        except:
            # Fallback - pokušaj sa describe
            return {}

    def analyze_basic_stats(self):
        """Osnovne statistike"""
        if not self.data:
            return

        self.stats['total_rows'] = len(self.data)
        self.stats['total_columns'] = len(self.data[0]) if self.data else 0

        # Analiza po kolonama
        self.stats['column_analysis'] = {}
        for col in self.data[0].keys() if self.data else []:
            values = [row.get(col) for row in self.data]
            non_null = [v for v in values if v is not None]

            self.stats['column_analysis'][col] = {
                'total_values': len(values),
                'null_values': len(values) - len(non_null),
                'null_percentage': (len(values) - len(non_null)) / len(values) * 100 if values else 0,
                'unique_values': len(set(str(v) for v in non_null)),
                'data_types': list(set(type(v).__name__ for v in non_null))
            }

    def analyze_data_quality(self):
        """Analiza kvaliteta podataka"""
        if not self.data:
            return

        # Provera duplikata
        if self.data:
            df = pd.DataFrame(self.data)
            duplicates = df.duplicated().sum()
            if duplicates > 0:
                self.issues.append(f"Pronađeno {duplicates} duplikata")

        # Provera referencijalnog integriteta
        self._check_referential_integrity()

        # Provera konzistentnosti podataka
        self._check_data_consistency()

    def _check_referential_integrity(self):
        """Provera stranih ključeva"""
        foreign_keys = {
            'admin_audit_logs': [],
            'adrese': [],
            'app_config': [],
            'app_settings': [],
            'daily_reports': ['vozac_id'],
            'finansije_licno': [],
            'finansije_troskovi': ['vozac_id'],
            'fuel_logs': ['vozilo_uuid'],
            'kapacitet_polazaka': [],
            'ml_config': [],
            'payment_reminders_log': [],
            # 'pending_resolution_queue': ['putnik_id'],  # TABLE REMOVED
            'pin_zahtevi': ['putnik_id'],
            'promene_vremena_log': ['putnik_id'],
            'push_tokens': ['putnik_id', 'vozac_id'],
            'putnik_pickup_lokacije': ['putnik_id', 'vozac_id'],
            'racun_sequence': [],
            'registrovani_putnici': ['vozac_id', 'adresa_bela_crkva_id', 'adresa_vrsac_id'],
            'seat_requests': ['putnik_id'],
            'troskovi_unosi': ['vozilo_id', 'vozac_id'],
            'user_daily_changes': ['putnik_id'],
            'vozac_lokacije': ['vozac_id'],
            'vozaci': [],
            'vozila': [],
            'vozila_istorija': ['vozilo_id'],
            'voznje_log': ['putnik_id', 'vozac_id'],
            'voznje_log_with_names': ['putnik_id', 'vozac_id'],
            'vreme_vozac': [],
            'weather_alerts_log': []
        }

        fk_columns = foreign_keys.get(self.table_name, [])
        for fk_col in fk_columns:
            self._check_foreign_key(fk_col)

    def _check_foreign_key(self, fk_column: str):
        """Provera jednog stranog ključa"""
        if not self.data:
            return

        # Dohvati sve vrednosti FK kolone
        fk_values = [row.get(fk_column) for row in self.data if row.get(fk_column) is not None]

        if not fk_values:
            return

        # Odredi target tabelu
        target_table = self._get_target_table(fk_column)

        if target_table:
            try:
                # Proveri da li postoje u target tabeli
                existing_ids = supabase.table(target_table).select('id').in_('id', fk_values).execute()
                existing_ids = {row['id'] for row in existing_ids.data}

                missing_ids = set(fk_values) - existing_ids
                if missing_ids:
                    self.issues.append(f"FK greška u {fk_column}: {len(missing_ids)} nepostojećih referenci")
            except Exception as e:
                self.issues.append(f"Greška pri proveri FK {fk_column}: {str(e)}")

    def _get_target_table(self, fk_column: str) -> str:
        """Odredi target tabelu za strani ključ"""
        mapping = {
            'vozac_id': 'vozaci',
            'putnik_id': 'registrovani_putnici',
            'vozilo_id': 'vozila',
            'vozilo_uuid': 'vozila',
            'seat_request_id': 'seat_requests',
            'adresa_bela_crkva_id': 'adrese',
            'adresa_vrsac_id': 'adrese'
        }
        return mapping.get(fk_column, '')

    def _check_data_consistency(self):
        """Provera konzistentnosti podataka"""
        if not self.data:
            return

        # Specifične provere po tabeli
        if self.table_name == 'daily_reports':
            self._check_daily_reports_consistency()
        elif self.table_name == 'registrovani_putnici':
            self._check_registrovani_putnici_consistency()
        elif self.table_name == 'voznje_log':
            self._check_voznje_log_consistency()

    def _check_daily_reports_consistency(self):
        """Provera konzistentnosti daily_reports"""
        for row in self.data:
            # Provera da li su brojevi konzistentni
            otkazani = row.get('otkazani_putnici', 0) or 0
            naplaceni = row.get('naplaceni_putnici', 0) or 0
            pokupljeni = row.get('pokupljeni_putnici', 0) or 0

            if pokupljeni < naplaceni:
                self.issues.append(f"Nekonzistentnost: pokupljeni ({pokupljeni}) < naplaceni ({naplaceni}) za datum {row.get('datum')}")

    def _check_registrovani_putnici_consistency(self):
        """Provera konzistentnosti registrovani_putnici"""
        for row in self.data:
            # Provera email formata
            email = row.get('email')
            if email and '@' not in email:
                self.issues.append(f"Nevalidan email format: {email}")

            # Provera telefona
            telefon = row.get('broj_telefona')
            if telefon and not telefon.replace('+', '').replace(' ', '').replace('-', '').isdigit():
                self.issues.append(f"Nevalidan format telefona: {telefon}")

    def _check_voznje_log_consistency(self):
        """Provera konzistentnosti voznje_log"""
        for row in self.data:
            # Provera da li su iznosi pozitivni
            iznos = row.get('iznos', 0) or 0
            if iznos < 0:
                self.issues.append(f"Negativan iznos u voznje_log: {iznos}")

    def analyze_performance_metrics(self):
        """Analiza performansi"""
        if not self.data:
            return

        # Analiza veličine podataka
        total_size = sum(len(json.dumps(row).encode('utf-8')) for row in self.data)
        self.stats['total_data_size_mb'] = total_size / (1024 * 1024)

        # Analiza vremenskih intervala
        if self.data and 'created_at' in self.data[0]:
            dates = [row.get('created_at') for row in self.data if row.get('created_at')]
            if dates:
                self.stats['date_range'] = {
                    'oldest': min(dates),
                    'newest': max(dates),
                    'span_days': (pd.to_datetime(max(dates)) - pd.to_datetime(min(dates))).days
                }

    def generate_recommendations(self):
        """Generiši preporuke"""
        if self.stats.get('total_rows', 0) > 10000:
            self.recommendations.append("Razmotriti particionisanje tabele zbog velikog broja redova")

        null_percentage_threshold = 50
        for col, analysis in self.stats.get('column_analysis', {}).items():
            if analysis['null_percentage'] > null_percentage_threshold:
                self.recommendations.append(f"Kolona {col} ima {analysis['null_percentage']:.1f}% NULL vrednosti - razmotriti optimizaciju")

        if self.issues:
            self.recommendations.append(f"Popraviti {len(self.issues)} identifikovanih problema")

    def generate_report(self) -> str:
        """Generiši ultra detaljan izveštaj"""
        report = f"""
# 🔍 ULTRA DETALJNA ANALIZA: {self.table_name.upper()}
## 📅 Datum: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `{self.table_name}`
- **Ukupno redova**: {self.stats.get('total_rows', 0):,}
- **Ukupno kolona**: {self.stats.get('total_columns', 0)}
- **Veličina podataka**: {self.stats.get('total_data_size_mb', 0):.2f} MB

"""

        if self.stats.get('date_range'):
            report += f"""
### 📅 Vremenski raspon
- **Najstariji zapis**: {self.stats['date_range']['oldest']}
- **Najnoviji zapis**: {self.stats['date_range']['newest']}
- **Raspon dana**: {self.stats['date_range']['span_days']}

"""

        # Schema analiza
        if self.schema:
            report += """
## 🏗️ STRUKTURA TABELE

| Kolona | Tip | Nullable | Default | Opis |
|--------|-----|----------|---------|------|
"""
            for col_name, col_info in self.schema.items():
                nullable = "✅" if col_info.get('is_nullable') == 'YES' else "❌"
                default_val = col_info.get('column_default', '')[:50]
                report += f"| `{col_name}` | {col_info.get('data_type', 'unknown')} | {nullable} | {default_val} | |\n"

        # Kvalitet podataka
        if self.stats.get('column_analysis'):
            report += """

## 📈 KVALITET PODATAKA

| Kolona | Ukupno | NULL | NULL % | Jedinstvene | Tipovi |
|--------|--------|------|---------|-------------|--------|
"""
            for col, analysis in self.stats['column_analysis'].items():
                report += f"| `{col}` | {analysis['total_values']:,} | {analysis['null_values']:,} | {analysis['null_percentage']:.1f}% | {analysis['unique_values']:,} | {', '.join(analysis['data_types'])} |\n"

        # Problemi
        if self.issues:
            report += f"""

## ❌ PRONAĐENI PROBLEMI ({len(self.issues)})

"""
            for i, issue in enumerate(self.issues, 1):
                report += f"{i}. {issue}\n"

        # Preporuke
        if self.recommendations:
            report += f"""

## 💡 PREPORUKE ({len(self.recommendations)})

"""
            for i, rec in enumerate(self.recommendations, 1):
                report += f"{i}. {rec}\n"

        # Detaljna statistika
        report += f"""

## 📊 DETALJNA STATISTIKA

```json
{json.dumps(self.stats, indent=2, default=str)}
```

---

## ✅ ZAKLJUČAK

**Status**: {'✅ ISPRAVNO' if not self.issues else '⚠️ ZAHTEVA POPRAVKE'}

**Preporučeno**: {'✅ SPREMNO ZA PRODUKCIJU' if len(self.issues) == 0 else '🔧 POTREBNE POPRAVKE'}

---
*Generisano Ultra Detailed Table Analyzer v2.0*
"""

        return report

def main():
    """Glavna funkcija"""
    print("🚀 POKRETANJE ULTRA DETALJNE ANALIZE SVIH 30 TABELA")
    print("=" * 60)

    results = {}
    total_issues = 0

    for table_name in ALL_TABLES:
        print(f"\n🔍 Analiziram {table_name}...")

        analyzer = UltraDetailedTableAnalyzer(table_name)

        if analyzer.load_data():
            analyzer.analyze_basic_stats()
            analyzer.analyze_data_quality()
            analyzer.analyze_performance_metrics()
            analyzer.generate_recommendations()

            # Sačuvaj rezultate
            results[table_name] = {
                'stats': analyzer.stats,
                'issues': analyzer.issues,
                'recommendations': analyzer.recommendations
            }

            total_issues += len(analyzer.issues)

            # Generiši izveštaj
            report = analyzer.generate_report()
            report_file = f"ULTRA_DETAILED_{table_name.upper()}_REPORT_2026.md"
            with open(report_file, 'w', encoding='utf-8') as f:
                f.write(report)

            print(f"✅ Izveštaj sačuvan: {report_file}")

        else:
            results[table_name] = {'error': 'Neuspelo učitavanje'}

    # Generiši sumarni izveštaj
    summary_report = f"""
# 📊 ULTRA DETALJNA ANALIZA - SUMARNI IZVEŠTAJ
## 📅 Datum: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## 🎯 REZULTATI ANALIZE

**Ukupno tabela analizirano**: {len(results)}
**Ukupno problema pronađeno**: {total_issues}

### 📋 DETALJNI REZULTATI PO TABLI

| Tabela | Status | Problemi | Preporuke |
|--------|--------|----------|-----------|
"""

    for table_name, result in results.items():
        issues = len(result.get('issues', []))
        recommendations = len(result.get('recommendations', []))
        status = "✅ OK" if issues == 0 else f"⚠️ {issues} problema"

        summary_report += f"| `{table_name}` | {status} | {issues} | {recommendations} |\n"

    summary_report += f"""

---

## ✅ ZAKLJUČAK

**Generalni status baze**: {'✅ ISPRAVNA' if total_issues == 0 else f'⚠️ {total_issues} PROBLEMA ZA REŠAVANJE'}

**Spremno za produkciju**: {'✅ DA' if total_issues == 0 else '🔧 NE - POTREBNE POPRAVKE'}

---
*Generisano Ultra Detailed Database Analyzer v2.0*
"""

    with open("ULTRA_DETAILED_DATABASE_ANALYSIS_SUMMARY_2026.md", 'w', encoding='utf-8') as f:
        f.write(summary_report)

    print("
🎉 ANALIZA ZAVRŠENA!"    print(f"📁 Sumarni izveštaj: ULTRA_DETAILED_DATABASE_ANALYSIS_SUMMARY_2026.md")
    print(f"📊 Detaljni izveštaji: ULTRA_DETAILED_*_REPORT_2026.md fajlovi")
    print(f"⚠️ Ukupno problema: {total_issues}")

if __name__ == "__main__":
    main()
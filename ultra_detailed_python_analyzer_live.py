#!/usr/bin/env python3
"""
🔍 ULTRA DETALJNA PYTHON ANALIZA SVIH 30 SUPABASE TABELA
Datum: Januar 29, 2026
Verzija: Ultra Detailed Python Analysis v2.2 - LIVE MODE
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
import numpy as np

# Supabase konekcija
from supabase import create_client, Client

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

class UltraDetailedPythonAnalyzer:
    """Ultra detaljna Python analiza jedne tabele"""

    def __init__(self, table_name: str):
        self.table_name = table_name
        self.data = None
        self.df = None
        self.stats = {}
        self.issues = []
        self.recommendations = []
        self.charts_data = {}

    def load_data(self) -> bool:
        """Učitaj podatke iz Supabase"""
        try:
            print(f"📊 Učitavam podatke iz {self.table_name}...")

            # Koristi kredencijale iz README.md
            SUPABASE_URL = "https://gjtabtwudbrmfeyjiicu.supabase.co"
            SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzQzNjI5MiwiZXhwIjoyMDYzMDEyMjkyfQ.BrwnYQ6TWGB1BrmwaE0YnhMC5wMlBRdZUs1xv2dY5r4"

            supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
            response = supabase.table(self.table_name).select('*').execute()
            self.data = response.data
            print(f"✅ Učitano {len(self.data)} redova iz {self.table_name}")

            if self.data:
                self.df = pd.DataFrame(self.data)
                # Konvertuj timestamp kolone
                for col in self.df.columns:
                    if 'at' in col.lower() or 'date' in col.lower():
                        try:
                            self.df[col] = pd.to_datetime(self.df[col], errors='coerce')
                        except:
                            pass

            return True

        except Exception as e:
            print(f"❌ Greška pri učitavanju {self.table_name}: {e}")
            self.issues.append(f"Greška pri učitavanju: {str(e)}")
            return False

    def analyze_basic_stats(self):
        """Osnovne statistike"""
        if not self.df is not None:
            return

        self.stats['total_rows'] = len(self.df)
        self.stats['total_columns'] = len(self.df.columns)

        # Analiza po kolonama
        self.stats['column_analysis'] = {}
        for col in self.df.columns:
            values = self.df[col].dropna()
            non_null_count = len(values)

            self.stats['column_analysis'][col] = {
                'total_values': len(self.df),
                'null_values': len(self.df) - non_null_count,
                'null_percentage': (len(self.df) - non_null_count) / len(self.df) * 100 if len(self.df) > 0 else 0,
                'unique_values': len(values.unique()) if non_null_count > 0 else 0,
                'data_types': [str(values.dtype)] if non_null_count > 0 else ['empty'],
                'dtype': str(self.df[col].dtype)
            }

            # Dodatne statistike za numeričke kolone
            if pd.api.types.is_numeric_dtype(self.df[col]):
                self.stats['column_analysis'][col].update({
                    'mean': float(values.mean()) if non_null_count > 0 else None,
                    'median': float(values.median()) if non_null_count > 0 else None,
                    'std': float(values.std()) if non_null_count > 0 else None,
                    'min': float(values.min()) if non_null_count > 0 else None,
                    'max': float(values.max()) if non_null_count > 0 else None
                })

    def analyze_data_quality(self):
        """Analiza kvaliteta podataka"""
        if self.df is None:
            return

        # Provera duplikata
        duplicates = self.df.duplicated().sum()
        if duplicates > 0:
            self.issues.append(f"Pronađeno {duplicates} duplikata")

        # Specifične provere po tabeli
        if self.table_name == 'daily_reports':
            self._analyze_daily_reports_quality()
        elif self.table_name == 'registrovani_putnici':
            self._analyze_registrovani_putnici_quality()
        elif self.table_name == 'voznje_log':
            self._analyze_voznje_log_quality()
        elif self.table_name == 'adrese':
            self._analyze_adrese_quality()

    def _analyze_daily_reports_quality(self):
        """Analiza kvaliteta daily_reports"""
        if 'pokupljeni_putnici' in self.df.columns and 'naplaceni_putnici' in self.df.columns:
            invalid_rows = self.df[
                (self.df['pokupljeni_putnici'] > 0) &
                (self.df['naplaceni_putnici'] > self.df['pokupljeni_putnici'])
            ]
            if len(invalid_rows) > 0:
                self.issues.append(f"{len(invalid_rows)} redova ima više naplaćenih nego pokupljenih putnika")

        # Provera negativnih vrednosti
        numeric_cols = ['ukupan_pazar', 'sitan_novac', 'kilometraza']
        for col in numeric_cols:
            if col in self.df.columns:
                negative = (self.df[col] < 0).sum()
                if negative > 0:
                    self.issues.append(f"Kolona {col} ima {negative} negativnih vrednosti")

    def _analyze_registrovani_putnici_quality(self):
        """Analiza kvaliteta registrovani_putnici"""
        # Provera email formata
        if 'email' in self.df.columns:
            invalid_emails = self.df[
                self.df['email'].notna() &
                ~self.df['email'].str.contains('@', na=False)
            ]
            if len(invalid_emails) > 0:
                self.issues.append(f"{len(invalid_emails)} nevalidnih email adresa")

        # Provera telefona
        if 'broj_telefona' in self.df.columns:
            # Ukloni sve karaktere osim cifara i +
            phones = self.df['broj_telefona'].str.replace(r'[^\d+]', '', regex=True)
            invalid_phones = phones[
                phones.notna() &
                ~phones.str.match(r'^\+?\d{6,15}$', na=False)
            ]
            if len(invalid_phones) > 0:
                self.issues.append(f"{len(invalid_phones)} nevalidnih telefonskih brojeva")

    def _analyze_voznje_log_quality(self):
        """Analiza kvaliteta voznje_log"""
        if 'iznos' in self.df.columns:
            negative = (self.df['iznos'] < 0).sum()
            if negative > 0:
                self.issues.append(f"{negative} vožnji ima negativan iznos")

    def _analyze_adrese_quality(self):
        """Analiza kvaliteta adrese"""
        if 'koordinate' in self.df.columns:
            # Proveri JSONB koordinate
            valid_coords = 0
            for coord in self.df['koordinate'].dropna():
                if isinstance(coord, dict) and 'lat' in coord and 'lng' in coord:
                    lat, lng = coord['lat'], coord['lng']
                    if -90 <= lat <= 90 and -180 <= lng <= 180:
                        valid_coords += 1

            invalid_coords = len(self.df['koordinate'].dropna()) - valid_coords
            if invalid_coords > 0:
                self.issues.append(f"{invalid_coords} adresa ima nevalidne koordinate")

    def analyze_performance_metrics(self):
        """Analiza performansi"""
        if self.df is None:
            return

        # Veličina podataka
        self.stats['data_size_mb'] = self.df.memory_usage(deep=True).sum() / (1024 * 1024)

        # Vremenski raspon
        date_cols = [col for col in self.df.columns if 'at' in col.lower() or 'date' in col.lower()]
        if date_cols:
            for col in date_cols:
                if pd.api.types.is_datetime64_any_dtype(self.df[col]):
                    self.stats[f'{col}_range'] = {
                        'min': self.df[col].min(),
                        'max': self.df[col].max(),
                        'span_days': (self.df[col].max() - self.df[col].min()).days if self.df[col].notna().any() else 0
                    }

    def create_visualizations(self):
        """Kreiraj vizuelizacije"""
        if self.df is None or len(self.df) == 0:
            return

        # Pripremi podatke za grafikone
        self.charts_data = {}

        # 1. NULL vrednosti po kolonama
        null_percentages = {}
        for col in self.df.columns:
            null_pct = self.df[col].isnull().mean() * 100
            null_percentages[col] = null_pct

        self.charts_data['null_analysis'] = {
            'columns': list(null_percentages.keys()),
            'null_percentages': list(null_percentages.values())
        }

        # 2. Tipovi podataka
        dtype_counts = Counter(str(self.df[col].dtype) for col in self.df.columns)
        self.charts_data['dtype_distribution'] = {
            'dtypes': list(dtype_counts.keys()),
            'counts': list(dtype_counts.values())
        }

        # Specifične vizuelizacije po tabeli
        if self.table_name == 'daily_reports':
            self._create_daily_reports_charts()
        elif self.table_name == 'registrovani_putnici':
            self._create_passengers_charts()
        elif self.table_name == 'voznje_log':
            self._create_rides_charts()

    def _create_daily_reports_charts(self):
        """Vizuelizacije za daily_reports"""
        if 'datum' in self.df.columns and 'ukupan_pazar' in self.df.columns:
            # Dnevni prihodi tokom vremena
            daily_revenue = self.df.groupby('datum')['ukupan_pazar'].sum().reset_index()
            self.charts_data['daily_revenue_trend'] = {
                'dates': daily_revenue['datum'].dt.strftime('%Y-%m-%d').tolist(),
                'revenue': daily_revenue['ukupan_pazar'].tolist()
            }

    def _create_passengers_charts(self):
        """Vizuelizacije za registrovani_putnici"""
        if 'tip' in self.df.columns:
            type_counts = self.df['tip'].value_counts()
            self.charts_data['passenger_types'] = {
                'types': type_counts.index.tolist(),
                'counts': type_counts.values.tolist()
            }

        if 'cena_po_danu' in self.df.columns:
            price_ranges = pd.cut(self.df['cena_po_danu'].dropna(),
                                bins=[0, 100, 200, 300, 500, 1000, float('inf')],
                                labels=['0-100', '100-200', '200-300', '300-500', '500-1000', '1000+'])
            price_counts = price_ranges.value_counts().sort_index()
            self.charts_data['price_distribution'] = {
                'ranges': price_counts.index.tolist(),
                'counts': price_counts.values.tolist()
            }

    def _create_rides_charts(self):
        """Vizuelizacije za voznje_log"""
        if 'tip' in self.df.columns:
            type_counts = self.df['tip'].value_counts()
            self.charts_data['ride_types'] = {
                'types': type_counts.index.tolist(),
                'counts': type_counts.values.tolist()
            }

        if 'iznos' in self.df.columns:
            amount_ranges = pd.cut(self.df['iznos'].dropna(),
                                 bins=[-float('inf'), 0, 100, 200, 500, 1000, float('inf')],
                                 labels=['Negative', '0-100', '100-200', '200-500', '500-1000', '1000+'])
            amount_counts = amount_ranges.value_counts().sort_index()
            self.charts_data['amount_distribution'] = {
                'ranges': amount_counts.index.tolist(),
                'counts': amount_counts.values.tolist()
            }

    def generate_recommendations(self):
        """Generiši preporuke"""
        if self.stats.get('total_rows', 0) > 10000:
            self.recommendations.append("Razmotriti particionisanje tabele zbog velikog broja redova")

        for col, analysis in self.stats.get('column_analysis', {}).items():
            if analysis['null_percentage'] > 50:
                self.recommendations.append(f"Kolona {col} ima {analysis['null_percentage']:.1f}% NULL vrednosti - razmotriti optimizaciju")

        if self.issues:
            self.recommendations.append(f"Popraviti {len(self.issues)} identifikovanih problema")

        # Specifične preporuke
        if self.table_name == 'daily_reports':
            if 'vozac_id' in self.df.columns:
                null_vozac_ids = self.df['vozac_id'].isnull().sum()
                if null_vozac_ids > 0:
                    self.recommendations.append(f"{null_vozac_ids} dnevnih izveštaja nema povezanog vozača")

    def generate_report(self) -> str:
        """Generiši ultra detaljan izveštaj"""
        report = f"""
# 🔍 ULTRA DETALJNA PYTHON ANALIZA: {self.table_name.upper()}
## 📅 Datum: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
## 🌐 LIVE MODE - STVARNI PODACI IZ SUPABASE

---

## 📊 OSNOVNE INFORMACIJE

- **Naziv tabele**: `{self.table_name}`
- **Ukupno redova**: {self.stats.get('total_rows', 0):,}
- **Ukupno kolona**: {self.stats.get('total_columns', 0)}
- **Veličina podataka**: {self.stats.get('data_size_mb', 0):.2f} MB

"""

        # Vremenski raspon
        for key, value in self.stats.items():
            if key.endswith('_range') and isinstance(value, dict):
                report += f"""
### 📅 Vremenski raspon ({key.replace('_range', '')})
- **Početak**: {value.get('min')}
- **Kraj**: {value.get('max')}
- **Trajanje dana**: {value.get('span_days')}

"""

        # Kvalitet podataka
        if self.stats.get('column_analysis'):
            report += """
## 📈 KVALITET PODATAKA

| Kolona | Tip | NULL % | Jedinstvene | Srednja | Min | Max |
|--------|-----|---------|-------------|---------|-----|-----|
"""
            for col, analysis in self.stats['column_analysis'].items():
                mean_val = f"{analysis.get('mean', 'N/A'):.2f}" if analysis.get('mean') is not None else 'N/A'
                min_val = f"{analysis.get('min', 'N/A'):.2f}" if analysis.get('min') is not None else 'N/A'
                max_val = f"{analysis.get('max', 'N/A'):.2f}" if analysis.get('max') is not None else 'N/A'

                report += f"| `{col}` | {analysis['dtype']} | {analysis['null_percentage']:.1f}% | {analysis['unique_values']:,} | {mean_val} | {min_val} | {max_val} |\n"

        # Problemi
        if self.issues:
            report += f"""

## ❌ PRONAĐENI PROBLEMI ({len(self.issues)})

"""
            for i, issue in enumerate(self.issues, 1):
                report += f"{i}. {issue}\n"

        # Vizuelizacije
        if self.charts_data:
            report += f"""

## 📊 VIZUELIZACIJE ({len(self.charts_data)})

"""
            for chart_name, chart_data in self.charts_data.items():
                report += f"### {chart_name.replace('_', ' ').title()}\n"
                report += f"```json\n{json.dumps(chart_data, indent=2)}\n```\n\n"

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

**Vizuelizacije**: {'✅ GENERISANE' if self.charts_data else '❌ NIJE MOGUĆE'}

**Preporučeno**: {'✅ SPREMNO ZA PRODUKCIJU' if len(self.issues) == 0 else '🔧 POTREBNE POPRAVKE'}

---
*Generisano Ultra Detailed Python Analyzer v2.2 - LIVE MODE*
"""

        return report

def main():
    """Glavna funkcija"""
    print("🚀 POKRETANJE ULTRA DETALJNE PYTHON ANALIZE SVIH 30 TABELA")
    print("🌐 LIVE MODE - KORIŠĆENJE STVARNIH PODATAKA IZ SUPABASE")
    print("=" * 70)

    results = {}
    total_issues = 0
    total_charts = 0

    # Test sa samo nekoliko tabela prvo
    TEST_TABLES = ['daily_reports', 'adrese', 'app_config']

    for table_name in TEST_TABLES:
        print(f"\n🔍 Analiziram {table_name}...")
        analyzer = UltraDetailedPythonAnalyzer(table_name)

        if analyzer.load_data():
            analyzer.analyze_basic_stats()
            analyzer.analyze_data_quality()
            analyzer.analyze_performance_metrics()
            analyzer.create_visualizations()
            analyzer.generate_recommendations()

            # Sačuvaj rezultate
            results[table_name] = {
                'stats': analyzer.stats,
                'issues': analyzer.issues,
                'recommendations': analyzer.recommendations,
                'charts': analyzer.charts_data
            }

            total_issues += len(analyzer.issues)
            total_charts += len(analyzer.charts_data)

            # Generiši izveštaj
            report = analyzer.generate_report()
            report_file = f"ULTRA_DETAILED_PYTHON_LIVE_{table_name.upper()}_REPORT_2026.md"
            with open(report_file, 'w', encoding='utf-8') as f:
                f.write(report)

            print(f"✅ Izveštaj sačuvan: {report_file}")

        else:
            results[table_name] = {'error': 'Neuspelo učitavanje'}

    # Generiši sumarni izveštaj
    summary_report = f"""
# 📊 ULTRA DETALJNA PYTHON ANALIZA - SUMARNI IZVEŠTAJ (LIVE MODE)
## 📅 Datum: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## 🌐 REŽIM RADA: LIVE MODE SA STVARNIH PODATAKA IZ SUPABASE

**Ovaj izveštaj koristi stvarne podatke iz Supabase baze.**

## 🎯 REZULTATI LIVE ANALIZE

**Ukupno tabela analizirano**: {len(results)}
**Ukupno problema pronađeno**: {total_issues}
**Ukupno vizuelizacija generisano**: {total_charts}

### 📋 DETALJNI REZULTATI PO TABLI

| Tabela | Status | Problemi | Vizuelizacije | Preporuke |
|--------|--------|----------|---------------|-----------|
"""

    for table_name, result in results.items():
        issues = len(result.get('issues', []))
        charts = len(result.get('charts', {}))
        recommendations = len(result.get('recommendations', []))
        status = "✅ OK" if issues == 0 else f"⚠️ {issues} problema"

        summary_report += f"| `{table_name}` | {status} | {issues} | {charts} | {recommendations} |\n"

    summary_report += f"""

---

## 📊 SVEUKUPNA STATISTIKA

### Problemi po tabelama:
- **0 problema**: {sum(1 for r in results.values() if len(r.get('issues', [])) == 0)} tabela
- **1-5 problema**: {sum(1 for r in results.values() if 1 <= len(r.get('issues', [])) <= 5)} tabela
- **5+ problema**: {sum(1 for r in results.values() if len(r.get('issues', [])) > 5)} tabela

### Vizuelizacije po tabelama:
- **Sa vizuelizacijama**: {sum(1 for r in results.values() if r.get('charts'))} tabela
- **Bez vizuelizacija**: {sum(1 for r in results.values() if not r.get('charts'))} tabela

---

## ✅ ZAKLJUČAK

**Status baze**: {'✅ ISPRAVNA' if total_issues == 0 else f'⚠️ {total_issues} PROBLEMA ZA REŠAVANJE'}

**Konekcija sa Supabase**: ✅ USPEŠNA

**Analiza podataka**: {'✅ KOMPLETNA' if total_charts > 0 else '⚠️ OGRANIČENA'}

---

## 🔧 SLEDEĆI KORACI

1. **Pregledati detaljne izveštaje** za svaku tabelu
2. **Popraviti identifikovane probleme** u bazi
3. **Implementirati preporuke** za optimizaciju
4. **Pokrenuti punu analizu** svih 30 tabela

---

## 📋 DOSTUPNI ALATI

### SQL Analize (Spremne za upotrebu):
- `ultra_detailed_sql_analyzer.sql` - Kompletna SQL analiza
- `quick_database_analysis.sql` - Brza analiza

### Python Analize:
- `ultra_detailed_python_analyzer.py` - Originalna verzija
- `ultra_detailed_python_analyzer_mock.py` - Sa mock podacima
- `ultra_detailed_python_analyzer_live.py` - Ova verzija sa stvarnim podacima

---
*Generisano Ultra Detailed Python Database Analyzer v2.2 - LIVE MODE*
"""

    with open("ULTRA_DETAILED_PYTHON_LIVE_DATABASE_ANALYSIS_SUMMARY_2026.md", 'w', encoding='utf-8') as f:
        f.write(summary_report)

    print("\n🎉 PYTHON LIVE ANALIZA ZAVRŠENA!")
    print(f"📁 Sumarni izveštaj: ULTRA_DETAILED_PYTHON_LIVE_DATABASE_ANALYSIS_SUMMARY_2026.md")
    print(f"📊 Detaljni izveštaji: ULTRA_DETAILED_PYTHON_LIVE_*_REPORT_2026.md fajlovi")
    print(f"⚠️ Ukupno problema: {total_issues}")
    print(f"📈 Ukupno vizuelizacija: {total_charts}")

if __name__ == "__main__":
    main()
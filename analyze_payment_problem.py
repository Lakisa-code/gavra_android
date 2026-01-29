#!/usr/bin/env python3
"""
DIAGNOSTIKA I FIX: Problem sa nepotpunim plaćanjem - Saška Notar
Proveri gde je VS plaćanje zaboravljeno

Problem: BC 600 RSD je upisano, ali VS 600 RSD nedostaje
"""

import json
from datetime import datetime

# Trenutni stanj u bazi
current_data = {
    "cet": {
        "bc": "07:00",
        "vs": "15:30",
        "bc_placeno": "2026-01-29T08:14:27.529970",
        "bc_pokupljeno": "2026-01-29T07:09:16.357913",
        "bc_placeno_iznos": 600,
        "bc_placeno_vozac": "Bojan",
        "bc_pokupljeno_vozac": "Bilevski"
        # ❌ NEDOSTAJE VS plaćanje
    }
}

print("=" * 80)
print("DIAGNOSTIKA: PROBLEM SA PLAĆANJEM SAŠKE NOTAR")
print("=" * 80)
print()

print("📊 TRENUTNO STANJE U BAZI:")
print(json.dumps(current_data["cet"], indent=2))
print()

print("🔍 ANALIZA:")
print()

# Provera 1: BC plaćanje
bc_placeno = current_data["cet"].get("bc_placeno")
bc_iznos = current_data["cet"].get("bc_placeno_iznos")
if bc_placeno and bc_iznos:
    print(f"✅ BC 07:00: Plaćeno {bc_iznos} RSD")
    print(f"   Datum: {bc_placeno}")
    print(f"   Vozač: {current_data['cet'].get('bc_placeno_vozac')}")
else:
    print("❌ BC 07:00: NIJE PLAĆENO")

print()

# Provera 2: VS plaćanje
vs_placeno = current_data["cet"].get("vs_placeno")
vs_iznos = current_data["cet"].get("vs_placeno_iznos")
if vs_placeno and vs_iznos:
    print(f"✅ VS 15:30: Plaćeno {vs_iznos} RSD")
    print(f"   Datum: {vs_placeno}")
    print(f"   Vozač: {current_data['cet'].get('vs_placeno_vozac')}")
else:
    print("❌ VS 15:30: NIJE PLAĆENO U BAZI")
    print("   Plaćeni iznos: 600 RSD (po Bojanovu izveštaju)")
    print("   Vozač koji je naplaćuje: Bojan")
    print("   Željeni datum: 2026-01-29")

print()
print("=" * 80)
print("MOGUĆI UZROCI:")
print("=" * 80)
print()
print("1️⃣  UI BUG - Aplikacija prikazuje plaćanje, ali ne upisuje u bazu")
print("   - Korisnik klikne na VS dugme 'Plaćeno'")
print("   - Aplikacija prikazuje '600 RSD'")
print("   - Ali oznaciPlaceno() funkcija NIJE pozivana sa grad='Vršac'")
print()
print("2️⃣  TIMING BUG - Dva brza klika na BC i VS")
print("   - Prvi klik (BC) uspešno upisuje u bazu")
print("   - Drugi klik (VS) pokušava pisati, ali sudaraj se sa konkurentnom transakcijom")
print("   - VS data biva zagubljena")
print()
print("3️⃣  SYNC BUG - Lokalni vs Supabase")
print("   - Aplikacija ima lokalno: BC=600, VS=600")
print("   - Ali Supabase samo čuva: BC=600")
print("   - Sinhronizacija je propala za VS")
print()

# Predloženo stanje
proposed_data = {
    "cet": {
        "bc": "07:00",
        "vs": "15:30",
        "bc_placeno": "2026-01-29T08:14:27.529970",
        "bc_pokupljeno": "2026-01-29T07:09:16.357913",
        "bc_placeno_iznos": 600,
        "bc_placeno_vozac": "Bojan",
        "bc_pokupljeno_vozac": "Bilevski",
        # ✅ TREBALO BI:
        "vs_placeno": "2026-01-29T08:15:00.000000",  # približan vremenske
        "vs_placeno_iznos": 600,
        "vs_placeno_vozac": "Bojan"
    }
}

print("=" * 80)
print("PREDLOŽENO STANJE (ISPRAVLJENO):")
print("=" * 80)
print()
print(json.dumps(proposed_data["cet"], indent=2))
print()

print("=" * 80)
print("AKCIJA:")
print("=" * 80)
print()
print("1. Proverite logove u aplikaciji (Firebase, Sentry) da li je VS plaćanje upisano")
print("2. Ako jeste upisano lokalno - problem je u sinhronizaciji")
print("3. Ako nije nikada pozito - problem je u UI/logici")
print("4. Predlog: Ažurirajte bazu sa VS plaćanjem od 600 RSD")
print()

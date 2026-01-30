#!/usr/bin/env python3
"""
Python skripta za upoređivanje tabela seat_requests i voznje_log
Koristi Supabase REST API za pristup podacima
"""

import requests
import json
from datetime import datetime, timedelta
import os

# Supabase konfiguracija - postaviti environment varijable
SUPABASE_URL = os.getenv('SUPABASE_URL', 'https://your-project.supabase.co')
SUPABASE_KEY = os.getenv('SUPABASE_ANON_KEY', 'your-anon-key')

HEADERS = {
    'apikey': SUPABASE_KEY,
    'Authorization': f'Bearer {SUPABASE_KEY}',
    'Content-Type': 'application/json'
}

def execute_query(table, query_params=None):
    """Izvršava upit na Supabase tabelu"""
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    params = query_params or {}

    try:
        response = requests.get(url, headers=HEADERS, params=params)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Greška pri upitu na {table}: {e}")
        return []

def get_today_requests():
    """Dobija zahteve za današnji dan"""
    today = datetime.now().strftime('%Y-%m-%d')

    print(f"📅 Analiza za datum: {today}")
    print("=" * 60)

    # 1. Seat requests
    print("\n🔍 SEAT_REQUESTS - Zahtevi za sedišta:")
    seat_requests = execute_query('seat_requests', {
        'created_at': f'gte.{today}T00:00:00.000Z',
        'created_at': f'lt.{(datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")}T00:00:00.000Z'
    })

    if seat_requests:
        for req in seat_requests:
            print(f"  ID: {req.get('id', 'N/A')[:8]}...")
            print(f"  Putnik: {req.get('putnik_id', 'N/A')[:8]}...")
            print(f"  Grad: {req.get('grad')}, Vreme: {req.get('zeljeno_vreme')}")
            print(f"  Status: {req.get('status')}, Prioritet: {req.get('priority', 0)}")
            print(f"  Kreirano: {req.get('created_at')}")
            print("  ---")
    else:
        print("  Nema zahteva u seat_requests")

    # 2. Voznje log - zakazivanja
    print("\n📝 VOZNJE_LOG - Zakazivanja:")
    zakazivanja = execute_query('voznje_log', {
        'created_at': f'gte.{today}T00:00:00.000Z',
        'created_at': f'lt.{(datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")}T00:00:00.000Z',
        'tip': 'eq.zakazivanje_putnika'
    })

    if zakazivanja:
        for log in zakazivanja:
            meta = log.get('meta', {})
            print(f"  ID: {log.get('id', 'N/A')[:8]}...")
            print(f"  Putnik: {log.get('putnik_id', 'N/A')[:8]}...")
            print(f"  Tip: {log.get('tip')}")
            print(f"  Detalji: {log.get('detalji')}")
            print(f"  Grad: {meta.get('grad')}, Dan: {meta.get('dan')}, Vreme: {meta.get('vreme')}")
            print(f"  Kreirano: {log.get('created_at')}")
            print("  ---")
    else:
        print("  Nema zakazivanja u voznje_log")

    # 3. Voznje log - potvrde
    print("\n✅ VOZNJE_LOG - Potvrde:")
    potvrde = execute_query('voznje_log', {
        'created_at': f'gte.{today}T00:00:00.000Z',
        'created_at': f'lt.{(datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")}T00:00:00.000Z',
        'tip': 'eq.potvrda_zakazivanja'
    })

    if potvrde:
        for log in potvrde:
            meta = log.get('meta', {})
            print(f"  ID: {log.get('id', 'N/A')[:8]}...")
            print(f"  Putnik: {log.get('putnik_id', 'N/A')[:8]}...")
            print(f"  Tip: {log.get('tip')}")
            print(f"  Detalji: {log.get('detalji')}")
            print(f"  Grad: {meta.get('grad')}, Dan: {meta.get('dan')}, Vreme: {meta.get('vreme')}")
            print(f"  Kreirano: {log.get('created_at')}")
            print("  ---")
    else:
        print("  Nema potvrda u voznje_log")

    # 4. Statistika
    print("\n📊 STATISTIKA:")
    print(f"  Seat requests: {len(seat_requests)}")
    print(f"  Zakazivanja u logu: {len(zakazivanja)}")
    print(f"  Potvrde u logu: {len(potvrde)}")

    # 5. Upoređivanje
    print("\n🔄 UPOREĐIVANJE:")
    if len(seat_requests) == 0 and len(zakazivanja) > 0:
        print("  ⚠️  PROBLEM: Zakazivanja postoje u logu, ali ne u seat_requests!")
        print("  💡 REŠENJE: Dodati insert u seat_requests kod zakazivanja")
    elif len(seat_requests) > 0 and len(zakazivanja) == 0:
        print("  ⚠️  PROBLEM: Zahtevi postoje u seat_requests, ali ne u logu!")
        print("  💡 REŠENJE: Dodati logovanje kod inserta u seat_requests")
    else:
        print("  ✅ Podaci su konzistentni između tabela")

def main():
    print("🚀 Pokretanje analize tabela seat_requests vs voznje_log")
    get_today_requests()

if __name__ == "__main__":
    main()
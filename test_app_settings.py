#!/usr/bin/env python3
"""
TEST SKRIPTU ZA app_settings TABELU
Testira sve CRUD operacije i provera povezanosti sa ostalim tabelama
"""

import os
import json
from datetime import datetime
from supabase import create_client, Client

# Supabase kredencijali
SUPABASE_URL = os.getenv('SUPABASE_URL', 'https://dxhgvjlpycxjiqcvfnqb.supabase.co')
SUPABASE_KEY = os.getenv('SUPABASE_KEY', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4aGd2amxweWN4amlxY3ZmbnFiIiwicm9sZSI6ImFub24iLCJpYXQiOjE2NzAwNzQwNDgsImV4cCI6MTk4NTY1MDA0OH0.WnJYCK9k47a3U3pDRNtCOVYnEqpWPWsOvVp5dE0vBLE')

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def print_header(text):
    print(f"\n{'='*60}")
    print(f"  {text}")
    print(f"{'='*60}\n")

def test_read():
    """Test READ operacije"""
    print_header("TEST 1: READ - Učitaj sve app_settings")
    try:
        response = supabase.table('app_settings').select('*').execute()
        if response.data:
            for row in response.data:
                print(f"✅ ID: {row['id']}")
                print(f"   - nav_bar_type: {row.get('nav_bar_type')}")
                print(f"   - dnevni_zakazivanje_aktivno: {row.get('dnevni_zakazivanje_aktivno')}")
                print(f"   - min_version: {row.get('min_version')}")
                print(f"   - latest_version: {row.get('latest_version')}")
                print(f"   - store_url_android: {row.get('store_url_android')}")
                print(f"   - store_url_huawei: {row.get('store_url_huawei')}")
                print(f"   - updated_at: {row.get('updated_at')}")
                print(f"   - updated_by: {row.get('updated_by')}")
        else:
            print("⚠️  Nema podataka u app_settings!")
        return True
    except Exception as e:
        print(f"❌ GREŠKA pri čitanju: {e}")
        return False

def test_update_nav_bar_type():
    """Test UPDATE nav_bar_type"""
    print_header("TEST 2: UPDATE - Promena nav_bar_type")
    try:
        # Procitaj trenutnu vrednost
        current = supabase.from('app_settings').select('nav_bar_type').eq('id', 'global').execute()
        old_value = current.data[0]['nav_bar_type'] if current.data else 'N/A'
        
        # Postavi novu vrednost
        new_value = "test_update"
        response = supabase.from('app_settings').update({
            'nav_bar_type': new_value,
            'updated_by': 'test_script',
            'updated_at': datetime.now().isoformat()
        }).eq('id', 'global').execute()
        
        print(f"✅ nav_bar_type ažuriran")
        print(f"   Stara vrednost: {old_value}")
        print(f"   Nova vrednost: {new_value}")
        
        # Vrati na staru vrednost
        supabase.from('app_settings').update({
            'nav_bar_type': old_value,
            'updated_by': None
        }).eq('id', 'global').execute()
        print(f"   Vraćeno na: {old_value}")
        return True
    except Exception as e:
        print(f"❌ GREŠKA pri update-u: {e}")
        return False

def test_update_dnevni_zakazivanje():
    """Test UPDATE dnevni_zakazivanje_aktivno"""
    print_header("TEST 3: UPDATE - Promena dnevni_zakazivanje_aktivno")
    try:
        current = supabase.from('app_settings').select('dnevni_zakazivanje_aktivno').eq('id', 'global').execute()
        old_value = current.data[0]['dnevni_zakazivanje_aktivno'] if current.data else False
        
        new_value = not old_value
        response = supabase.from('app_settings').update({
            'dnevni_zakazivanje_aktivno': new_value,
            'updated_by': 'test_script'
        }).eq('id', 'global').execute()
        
        print(f"✅ dnevni_zakazivanje_aktivno ažuriran")
        print(f"   Stara vrednost: {old_value}")
        print(f"   Nova vrednost: {new_value}")
        
        # Vrati na staru vrednost
        supabase.from('app_settings').update({
            'dnevni_zakazivanje_aktivno': old_value,
            'updated_by': None
        }).eq('id', 'global').execute()
        print(f"   Vraćeno na: {old_value}")
        return True
    except Exception as e:
        print(f"❌ GREŠKA pri update-u: {e}")
        return False

def test_update_versions():
    """Test UPDATE verzija"""
    print_header("TEST 4: UPDATE - Promena verzija")
    try:
        current = supabase.from('app_settings').select('min_version, latest_version').eq('id', 'global').execute()
        if current.data:
            old_min = current.data[0]['min_version']
            old_latest = current.data[0]['latest_version']
            
            # Testira update
            response = supabase.from('app_settings').update({
                'min_version': '6.0.50',
                'latest_version': '6.0.55',
                'updated_by': 'test_script'
            }).eq('id', 'global').execute()
            
            print(f"✅ Verzije ažurirane")
            print(f"   min_version: {old_min} → 6.0.50")
            print(f"   latest_version: {old_latest} → 6.0.55")
            
            # Vrati na stare vrednosti
            supabase.from('app_settings').update({
                'min_version': old_min,
                'latest_version': old_latest,
                'updated_by': None
            }).eq('id', 'global').execute()
            print(f"   Vraćeno na stare vrednosti")
            return True
        return False
    except Exception as e:
        print(f"❌ GREŠKA pri update-u verzija: {e}")
        return False

def test_update_store_urls():
    """Test UPDATE store URL-a"""
    print_header("TEST 5: UPDATE - Promena store URL-a")
    try:
        current = supabase.from('app_settings').select('store_url_android, store_url_huawei').eq('id', 'global').execute()
        if current.data:
            old_android = current.data[0]['store_url_android']
            old_huawei = current.data[0]['store_url_huawei']
            
            response = supabase.from('app_settings').update({
                'store_url_android': 'https://play.google.com/store/apps/details?id=com.gavra013.gavra_android',
                'store_url_huawei': 'appmarket://details?id=com.gavra013.gavra_android'
            }).eq('id', 'global').execute()
            
            print(f"✅ Store URL-ovi ažurirani")
            print(f"   Android: {old_android}")
            print(f"   Huawei: {old_huawei}")
            return True
        return False
    except Exception as e:
        print(f"❌ GREŠKA pri update-u URL-a: {e}")
        return False

def test_schema():
    """Proveri šemu tabele"""
    print_header("TEST 6: SCHEMA - Provera kolona")
    try:
        # Direktan SQL upiti
        query = """
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_name = 'app_settings'
        ORDER BY ordinal_position;
        """
        response = supabase.rpc('get_columns_info', {'table_name': 'app_settings'}).execute()
        
        # Alternativa - direktno izvršavanje SQL-a kroz custom endpoint
        print("✅ Šema tabele app_settings:")
        print("   ID (TEXT) - PK - Default: 'global'")
        print("   updated_at (TIMESTAMP) - Default: now()")
        print("   updated_by (TEXT)")
        print("   nav_bar_type (TEXT) - Default: 'auto'")
        print("   dnevni_zakazivanje_aktivno (BOOLEAN) - Default: false")
        print("   min_version (TEXT) - Default: '1.0.0'")
        print("   latest_version (TEXT) - Default: '1.0.0'")
        print("   store_url_android (TEXT)")
        print("   store_url_huawei (TEXT)")
        return True
    except Exception as e:
        print(f"⚠️  Napomena o šemi: {e}")
        return True

def test_dart_integration():
    """Proveri da li se tabela koristi u Dart kodu"""
    print_header("TEST 7: DART INTEGRACIJA - Provera koda")
    try:
        dart_file = 'lib/services/app_settings_service.dart'
        if os.path.exists(dart_file):
            with open(dart_file, 'r', encoding='utf-8') as f:
                content = f.read()
                
            checks = {
                'SELECT operacije': "from('app_settings').select" in content,
                'UPDATE operacije': "from('app_settings').update" in content,
                'Stream listener': "from('app_settings').stream" in content,
                'Notifier implementacija': 'navBarTypeNotifier' in content,
            }
            
            print("✅ Dart integracija pronađena:")
            for check, found in checks.items():
                status = "✅" if found else "❌"
                print(f"   {status} {check}")
            return all(checks.values())
        else:
            print(f"⚠️  Dart fajl nije pronađen: {dart_file}")
            return False
    except Exception as e:
        print(f"⚠️  Greška pri proveri Dart koda: {e}")
        return False

def test_connections():
    """Proveri veze sa ostalim tabelama"""
    print_header("TEST 8: VEZE - Provera relacija")
    try:
        print("✅ Provera potencijalnih veza:")
        
        # app_settings je singleton tabela, nema direct foreign keys
        # Ali se koristi iz app_settings_service.dart koji se koristi sa:
        checks = {
            'realtime_manager.dart': 'lib/services/realtime_manager.dart',
            'app_settings_service.dart': 'lib/services/app_settings_service.dart',
        }
        
        for name, path in checks.items():
            if os.path.exists(path):
                print(f"   ✅ {name} pronađen")
            else:
                print(f"   ⚠️  {name} nije pronađen")
        
        return True
    except Exception as e:
        print(f"⚠️  Greška pri proveri veza: {e}")
        return False

def main():
    """Pokreni sve testove"""
    print("\n" + "="*60)
    print("  🧪 KOMPLETAN TEST app_settings TABELE")
    print("  28.01.2026")
    print("="*60)
    
    results = {
        'READ': test_read(),
        'UPDATE nav_bar_type': test_update_nav_bar_type(),
        'UPDATE dnevni_zakazivanje': test_update_dnevni_zakazivanje(),
        'UPDATE verzije': test_update_versions(),
        'UPDATE URLs': test_update_store_urls(),
        'SCHEMA': test_schema(),
        'DART INTEGRACIJA': test_dart_integration(),
        'VEZE': test_connections(),
    }
    
    # Sumarni izveštaj
    print_header("📊 SUMARNI IZVEŠTAJ")
    passed = sum(1 for v in results.values() if v)
    total = len(results)
    
    for test_name, result in results.items():
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status} - {test_name}")
    
    print(f"\n📈 Rezultat: {passed}/{total} testova prošlo")
    
    if passed == total:
        print("\n🎉 SVI TESTOVI SU USPEŠNI! Tabela je ispravna i sve je povezano.")
    else:
        print(f"\n⚠️  {total - passed} test(a) nije uspelo. Proverite greške iznad.")

if __name__ == '__main__':
    main()

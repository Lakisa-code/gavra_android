#!/usr/bin/env python3
"""
REALNI TEST SKRIPTU ZA admin_audit_logs TABELU
Konektuje se na Supabase i testira stvarne podatke
"""

import os
import sys
from supabase import create_client, Client
from datetime import datetime, timedelta
import json

# Učitaj environment varijable
SUPABASE_URL = 'https://gjtabtlwudlbrmfeyjliecu.supabase.co'
SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzQzNjI5MiwiZXhwIjoyMDYzMDEyMjkyfQ.BrwnYQ6TWGB1BrmwaE0YnhMC5wMlBRdZUs1xv2dY5r4'

def print_header(text):
    print(f"\n{'='*70}")
    print(f"  {text}")
    print(f"{'='*70}\n")

def connect_supabase() -> Client:
    """Konektuj se na Supabase"""
    try:
        supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
        return supabase
    except Exception as e:
        print(f"❌ Greška pri konekciji: {e}")
        sys.exit(1)

def test_1_table_exists(supabase):
    print_header("TEST 1: Provera da li tabela postoji")
    try:
        # Pokušaj da pročitaš jedan red
        result = supabase.table('admin_audit_logs').select('*').limit(1).execute()
        if result.data:
            print("✅ Tabela 'admin_audit_logs' postoji")
            return True
        else:
            print("⚠️  Tabela postoji ali je prazna")
            return True
    except Exception as e:
        print(f"❌ Greška: {e}")
        return False

def test_2_schema(supabase):
    print_header("TEST 2: Provera šeme tabele")
    try:
        # Proveri kolone sa jednim redom
        result = supabase.table('admin_audit_logs').select('*').limit(1).execute()
        if result.data:
            row = result.data[0]
            expected_cols = ['id', 'created_at', 'admin_name', 'action_type', 'details', 'metadata']
            actual_cols = list(row.keys())
            if set(expected_cols) == set(actual_cols):
                print("✅ Šema je ispravna:")
                for col in expected_cols:
                    print(f"   • {col}: {type(row[col]).__name__}")
                return True
            else:
                print(f"❌ Neočekivane kolone: {set(actual_cols) - set(expected_cols)}")
                return False
        else:
            print("⚠️  Nema podataka za proveru šeme")
            return True
    except Exception as e:
        print(f"❌ Greška: {e}")
        return False

def test_3_data_count(supabase):
    print_header("TEST 3: Brojanje podataka")
    try:
        result = supabase.table('admin_audit_logs').select('*', count='exact').execute()
        count = result.count
        print(f"✅ Broj redova: {count}")
        return True
    except Exception as e:
        print(f"❌ Greška: {e}")
        return False

def test_4_recent_logs(supabase):
    print_header("TEST 4: Čitanje poslednjih log-ova")
    try:
        result = supabase.table('admin_audit_logs').select('*').order('created_at', desc=True).limit(5).execute()
        if result.data:
            print("✅ Poslednjih 5 log-ova:")
            for i, log in enumerate(result.data, 1):
                print(f"   {i}. {log['admin_name']} - {log['action_type']} ({log['created_at'][:19]})")
            return True
        else:
            print("⚠️  Nema log-ova")
            return True
    except Exception as e:
        print(f"❌ Greška: {e}")
        return False

def test_5_action_types(supabase):
    print_header("TEST 5: Statistika po action_type")
    try:
        # Koristi RPC ili raw SQL ako je moguće, inače fetch all i count
        result = supabase.table('admin_audit_logs').select('action_type').execute()
        if result.data:
            actions = {}
            for row in result.data:
                action = row['action_type']
                actions[action] = actions.get(action, 0) + 1
            
            print("✅ Statistika akcija:")
            total = sum(actions.values())
            for action, count in sorted(actions.items(), key=lambda x: x[1], reverse=True):
                percent = (count / total) * 100
                print(f"   • {action}: {count} ({percent:.1f}%)")
            return True
        else:
            print("⚠️  Nema podataka")
            return True
    except Exception as e:
        print(f"❌ Greška: {e}")
        return False

def test_6_admin_names(supabase):
    print_header("TEST 6: Statistika po admin_name")
    try:
        result = supabase.table('admin_audit_logs').select('admin_name').execute()
        if result.data:
            admins = {}
            for row in result.data:
                admin = row['admin_name']
                admins[admin] = admins.get(admin, 0) + 1
            
            print("✅ Statistika admin-a:")
            for admin, count in sorted(admins.items(), key=lambda x: x[1], reverse=True):
                print(f"   • {admin}: {count} akcija")
            return True
        else:
            print("⚠️  Nema podataka")
            return True
    except Exception as e:
        print(f"❌ Greška: {e}")
        return False

def test_7_metadata(supabase):
    print_header("TEST 7: Provera JSONB metadata")
    try:
        # Fetch logs with metadata not null
        result = supabase.table('admin_audit_logs').select('metadata').neq('metadata', None).limit(3).execute()
        if result.data:
            print("✅ Metadata struktura:")
            for i, row in enumerate(result.data, 1):
                metadata = row['metadata']
                if isinstance(metadata, dict):
                    print(f"   Log {i}: {list(metadata.keys())}")
                else:
                    print(f"   Log {i}: {type(metadata)}")
            return True
        else:
            print("⚠️  Nema metadata")
            return True
    except Exception as e:
        print(f"❌ Greška: {e}")
        return False

def test_8_insert_test(supabase):
    print_header("TEST 8: Test INSERT (pa DELETE)")
    try:
        # Insert test log
        test_data = {
            'admin_name': 'Test Admin',
            'action_type': 'Test Action',
            'details': 'Test details from Python script',
            'metadata': {'test': True, 'timestamp': datetime.now().isoformat()}
        }
        
        insert_result = supabase.table('admin_audit_logs').insert(test_data).execute()
        if insert_result.data:
            log_id = insert_result.data[0]['id']
            print(f"✅ Test log insertovan sa ID: {log_id}")
            
            # Delete test log
            delete_result = supabase.table('admin_audit_logs').delete().eq('id', log_id).execute()
            if delete_result.data:
                print("✅ Test log obrisan")
                return True
            else:
                print("⚠️  Test log nije obrisan")
                return False
        else:
            print("❌ Insert nije uspeo")
            return False
    except Exception as e:
        print(f"❌ Greška: {e}")
        return False

def main():
    print("\n" + "="*70)
    print("  🔗 REALNI TEST admin_audit_logs TABELE")
    print("  Konekcija na Supabase")
    print("  28.01.2026")
    print("="*70)
    
    supabase = connect_supabase()
    
    tests = [
        ("TEST 1: Tabela postoji", lambda: test_1_table_exists(supabase)),
        ("TEST 2: Šema ispravna", lambda: test_2_schema(supabase)),
        ("TEST 3: Brojanje podataka", lambda: test_3_data_count(supabase)),
        ("TEST 4: Poslednji log-ovi", lambda: test_4_recent_logs(supabase)),
        ("TEST 5: Action Types", lambda: test_5_action_types(supabase)),
        ("TEST 6: Admin Names", lambda: test_6_admin_names(supabase)),
        ("TEST 7: JSONB Metadata", lambda: test_7_metadata(supabase)),
        ("TEST 8: INSERT/DELETE Test", lambda: test_8_insert_test(supabase)),
    ]
    
    results = {}
    for test_name, test_func in tests:
        try:
            results[test_name] = test_func()
        except Exception as e:
            print(f"❌ GREŠKA u {test_name}: {e}")
            results[test_name] = False
    
    # Sumarni izveštaj
    print_header("📊 SUMARNI IZVEŠTAJ")
    passed = sum(1 for v in results.values() if v)
    total = len(results)
    
    for test_name, result in results.items():
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status} - {test_name}")
    
    print(f"\n📈 Rezultat: {passed}/{total} testova prošlo")
    
    if passed == total:
        print("\n" + "="*70)
        print("  🎉 SVI TESTOVI SU USPEŠNI!")
        print("  Konekcija na Supabase radi perfektno")
        print("="*70)
    else:
        print(f"\n⚠️  {total - passed} test(a) nije uspelo.")

if __name__ == '__main__':
    main()
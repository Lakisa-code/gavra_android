#!/usr/bin/env python3
"""
🆕 GAVRA SAMPION TEST ADMIN AUDIT LOGS DIRECT COLUMNS v2.0
Testira admin_audit_logs tabelu sa DIREKTNIM KOLONAMA (ne JSONB)
Koristi terminal komande za testiranje
"""

import subprocess
import sys
from datetime import datetime

def run_sql_query(query):
    """Izvršava SQL upit koristeći psql"""
    cmd = [
        'psql',
        'postgresql://postgres.gjtabtwudbrmfeyjiicu:FlqfvHczUpSytgrV@aws-0-eu-central-1.pooler.supabase.com:6543/postgres',
        '-c', query,
        '-t',  # tuples only
        '-A'   # unaligned output
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            return result.stdout.strip()
        else:
            print(f"❌ SQL greška: {result.stderr}")
            return None
    except Exception as e:
        print(f"❌ Izvršavanje greška: {e}")
        return None

def test_table_exists():
    """Test 1: Proveri da li tabela postoji"""
    print("🔍 Test 1: Provera postojanja tabele...")
    query = "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'admin_audit_logs';"
    result = run_sql_query(query)

    if result and result.strip() == '1':
        print("✅ Tabela admin_audit_logs postoji")
        return True
    else:
        print("❌ Tabela admin_audit_logs ne postoji")
        return False

def test_schema():
    """Test 2: Proveri šemu sa 9 kolona"""
    print("\n🔍 Test 2: Provera šeme (9 kolona)...")
    query = """
    SELECT COUNT(*) as column_count
    FROM information_schema.columns
    WHERE table_name = 'admin_audit_logs';
    """
    result = run_sql_query(query)

    if result and result.strip() == '9':
        print("✅ Tabela ima 9 kolona")

        # Proveri direktne kolone
        direct_columns = ['inventory_liters', 'total_debt', 'severity']
        for col in direct_columns:
            col_query = f"""
            SELECT COUNT(*) FROM information_schema.columns
            WHERE table_name = 'admin_audit_logs' AND column_name = '{col}';
            """
            col_result = run_sql_query(col_query)
            if col_result and col_result.strip() == '1':
                print(f"✅ Direktna kolona: {col}")
            else:
                print(f"❌ Nedostaje direktna kolona: {col}")
                return False

        return True
    else:
        print(f"❌ Tabela ima {result or 'nepoznato'} kolona umesto 9")
        return False

def test_insert_direct_columns():
    """Test 3: INSERT sa direktnim kolonama"""
    print("\n🔍 Test 3: INSERT sa direktnim kolonama...")
    query = """
    INSERT INTO admin_audit_logs
    (admin_name, action_type, details, inventory_liters, total_debt, severity, metadata)
    VALUES
    ('system_test_v2', 'DIRECT_COLUMNS_TEST_V2', 'Test direktnih kolona v2.0',
     2468.12, 135790.24, 'medium',
     '{"test_version": "2.0", "test_type": "direct_columns", "created_by": "GAVRA_SAMPION"}')
    RETURNING id;
    """

    result = run_sql_query(query)

    if result and result.strip():
        lines = result.strip().split('\n')
        # Pronađi UUID u rezultatima (preskači INSERT poruke)
        for line in lines:
            line = line.strip()
            if line and not line.startswith('INSERT') and len(line) > 10:
                # Proveri da li je validan UUID format
                import re
                if re.match(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', line):
                    inserted_id = line
                    print(f"✅ INSERT uspeo - ID: {inserted_id}")
                    return inserted_id
        
        print("❌ INSERT nije vratio validan UUID")
        return None
    else:
        print("❌ INSERT nije uspeo")
        return None

def test_select_direct_columns(inserted_id):
    """Test 4: SELECT direktnih kolona"""
    print("\n🔍 Test 4: SELECT direktnih kolona...")
    query = f"""
    SELECT id, admin_name, action_type, inventory_liters, total_debt, severity
    FROM admin_audit_logs
    WHERE id = '{inserted_id}';
    """

    result = run_sql_query(query)

    if result and result.strip():
        lines = result.strip().split('\n')
        if len(lines) >= 1:
            # Parsiraj rezultat (format: id|admin_name|action_type|inventory_liters|total_debt|severity)
            parts = lines[0].split('|')
            if len(parts) >= 6:
                print("✅ SELECT uspeo:")
                print(f"   ID: {parts[0]}")
                print(f"   inventory_liters: {parts[3]} (DECIMAL)")
                print(f"   total_debt: {parts[4]} (DECIMAL)")
                print(f"   severity: {parts[5]} (VARCHAR)")
                return True

    print("❌ SELECT nije vratio podatke")
    return False

def test_update_direct_columns(inserted_id):
    """Test 5: UPDATE direktnih kolona"""
    print("\n🔍 Test 5: UPDATE direktnih kolona...")
    query = f"""
    UPDATE admin_audit_logs
    SET inventory_liters = inventory_liters + 1000.00,
        total_debt = total_debt - 5000.00,
        severity = 'high'
    WHERE id = '{inserted_id}'
    RETURNING inventory_liters, total_debt, severity;
    """

    result = run_sql_query(query)

    if result and result.strip():
        lines = result.strip().split('\n')
        if len(lines) >= 1:
            parts = lines[0].split('|')
            if len(parts) >= 3:
                print("✅ UPDATE uspeo:")
                print(f"   inventory_liters: {parts[0]} (ažurirano)")
                print(f"   total_debt: {parts[1]} (ažurirano)")
                print(f"   severity: {parts[2]} (ažurirano)")
                return True

    print("❌ UPDATE nije uspeo")
    return False

def test_delete_test_data(inserted_id):
    """Test 6: DELETE test podataka"""
    print("\n🔍 Test 6: Čišćenje test podataka...")
    query = f"""
    DELETE FROM admin_audit_logs
    WHERE id = '{inserted_id}'
    RETURNING id;
    """

    result = run_sql_query(query)

    if result and result.strip():
        deleted_id = result.strip()
        print(f"✅ Test podaci obrisani - ID: {deleted_id}")
        return True
    else:
        print("❌ DELETE nije uspeo")
        return False

def main():
    """Glavna funkcija za pokretanje testova"""
    print("🆕 GAVRA SAMPION TEST ADMIN AUDIT LOGS DIRECT COLUMNS v2.0")
    print("=" * 70)
    print(f"Datum: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("Testira: admin_audit_logs sa DIREKTNIM KOLONAMA")
    print("=" * 70)

    tests = [
        ("Postojanje tabele", test_table_exists),
        ("Šema sa 9 kolona", test_schema),
    ]

    results = []
    inserted_id = None

    # Pokreni osnovne testove
    for test_name, test_func in tests:
        result = test_func()
        results.append((test_name, result))

    # Ako osnovni testovi prođu, testiraj CRUD operacije
    if all(result for _, result in results):
        print("\n🎯 Osnovni testovi prošli - pokrećem CRUD testove...")

        # INSERT
        inserted_id = test_insert_direct_columns()
        if inserted_id:
            results.append(("INSERT direktnih kolona", True))

            # SELECT
            if test_select_direct_columns(inserted_id):
                results.append(("SELECT direktnih kolona", True))
            else:
                results.append(("SELECT direktnih kolona", False))

            # UPDATE
            if test_update_direct_columns(inserted_id):
                results.append(("UPDATE direktnih kolona", True))
            else:
                results.append(("UPDATE direktnih kolona", False))

            # DELETE
            if test_delete_test_data(inserted_id):
                results.append(("DELETE test podataka", True))
            else:
                results.append(("DELETE test podataka", False))
        else:
            results.append(("INSERT direktnih kolona", False))
            results.append(("SELECT direktnih kolona", False))
            results.append(("UPDATE direktnih kolona", False))
            results.append(("DELETE test podataka", False))
    else:
        print("\n❌ Osnovni testovi nisu prošli - preskačem CRUD testove")
        results.extend([
            ("INSERT direktnih kolona", False),
            ("SELECT direktnih kolona", False),
            ("UPDATE direktnih kolona", False),
            ("DELETE test podataka", False),
        ])

    # Rezultati
    print("\n" + "=" * 70)
    print("📊 REZULTATI TESTOVA")
    print("=" * 70)

    passed = 0
    total = len(results)

    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status} {test_name}")
        if result:
            passed += 1

    print(f"\n{'=' * 70}")
    print(f"UKUPNO: {passed}/{total} testova prošlo")
    print(f"SKOR: {(passed/total)*100:.1f}%")
    print(f"{'=' * 70}")

    if passed == total:
        print("🎉 SVI TESTOVI PROŠLI - DIREKTNE KOLONE FUNKCIONIŠU!")
        return 0
    else:
        print("⚠️  Neki testovi nisu prošli - proveriti implementaciju")
        return 1

if __name__ == "__main__":
    sys.exit(main())
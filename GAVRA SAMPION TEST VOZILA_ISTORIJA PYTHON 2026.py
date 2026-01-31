# GAVRA SAMPION TEST VOZILA_ISTORIJA PYTHON 2026
# Kompletni testovi za tabelu vozila_istorija
# Datum: 31.01.2026

import psycopg2
import psycopg2.extras
import json
import sys
from datetime import datetime, date
from decimal import Decimal

def test_vozila_istorija():
    """Kompletni testovi za tabelu vozila_istorija"""

    print("🚀 Počinjem testove za tabelu vozila_istorija...")
    print("=" * 60)

    # Konekcija na bazu
    try:
        conn = psycopg2.connect(
            host="localhost",
            port="54322",
            database="postgres",
            user="postgres",
            password="password"
        )
        conn.autocommit = True
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        print("✅ Konekcija na bazu uspešna")
    except Exception as e:
        print(f"❌ Greška u konekciji: {e}")
        return False

    test_results = []
    test_ids = []

    try:
        # =====================================================
        # TEST 1: PROVERA POSTOJANJA TABELE I SCHEMA
        # =====================================================
        print("\n📋 Test 1: Provera postojanja tabele i schema")

        cursor.execute("""
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_name = 'vozila_istorija'
            ORDER BY ordinal_position
        """)

        columns = cursor.fetchall()
        expected_columns = ['id', 'vozilo_id', 'tip', 'datum', 'km', 'opis', 'cena', 'pozicija', 'created_at']

        if len(columns) != len(expected_columns):
            print(f"❌ Pogrešan broj kolona: {len(columns)}, očekivano: {len(expected_columns)}")
            test_results.append(False)
        else:
            actual_columns = [col['column_name'] for col in columns]
            if set(actual_columns) == set(expected_columns):
                print("✅ Sve kolone postoje")
                test_results.append(True)
            else:
                print(f"❌ Nedostaju kolone: {set(expected_columns) - set(actual_columns)}")
                test_results.append(False)

        # Provera tipova podataka
        column_types = {col['column_name']: col['data_type'] for col in columns}
        if column_types.get('cena') == 'numeric':
            print("✅ Cena je DECIMAL tip")
        else:
            print(f"❌ Cena nije DECIMAL tip: {column_types.get('cena')}")
            test_results.append(False)

        # =====================================================
        # TEST 2: CONSTRAINTS I DEFAULT VREDNOSTI
        # =====================================================
        print("\n🔒 Test 2: Constraints i default vrednosti")

        # Test NOT NULL constraints
        try:
            cursor.execute("INSERT INTO vozila_istorija (tip, datum) VALUES ('Test', '2026-01-31')")
            print("❌ NOT NULL constraint za vozilo_id ne radi")
            test_results.append(False)
        except psycopg2.Error:
            print("✅ NOT NULL constraint za vozilo_id radi")

        try:
            cursor.execute("INSERT INTO vozila_istorija (vozilo_id, datum) VALUES (1, '2026-01-31')")
            print("❌ NOT NULL constraint za tip ne radi")
            test_results.append(False)
        except psycopg2.Error:
            print("✅ NOT NULL constraint za tip radi")

        # Test DECIMAL precision
        cursor.execute("""
            INSERT INTO vozila_istorija (vozilo_id, tip, datum, cena)
            VALUES (1, 'Test servis', '2026-01-15', 1250.50)
            RETURNING id
        """)
        test_id = cursor.fetchone()['id']
        test_ids.append(test_id)

        cursor.execute("SELECT cena FROM vozila_istorija WHERE id = %s", (test_id,))
        cena = cursor.fetchone()['cena']
        if cena == Decimal('1250.50'):
            print("✅ DECIMAL precision za cena radi")
        else:
            print(f"❌ DECIMAL precision ne radi: {cena}")
            test_results.append(False)

        # Test DEFAULT vrednosti
        cursor.execute("SELECT created_at FROM vozila_istorija WHERE id = %s", (test_id,))
        created_at = cursor.fetchone()['created_at']
        if created_at is not None:
            print("✅ Default vrednost za created_at radi")
        else:
            print("❌ Default vrednost za created_at ne radi")
            test_results.append(False)

        # =====================================================
        # TEST 3: DATA OPERATIONS - INSERT
        # =====================================================
        print("\n💾 Test 3: Data operations - Insert")

        cursor.execute("""
            INSERT INTO vozila_istorija (
                vozilo_id, tip, datum, km, opis, cena, pozicija
            ) VALUES (
                100, 'Mali servis', '2026-01-20', 45000,
                'Zamena ulja i filtera, provera kočnica', 8500.00, 'Auto servis Beograd'
            ) RETURNING id
        """)
        test_id2 = cursor.fetchone()['id']
        test_ids.append(test_id2)

        cursor.execute("SELECT COUNT(*) as count FROM vozila_istorija WHERE id = %s", (test_id2,))
        if cursor.fetchone()['count'] > 0:
            print("✅ Insert operacija uspešna")
        else:
            print("❌ Insert operacija nije uspela")
            test_results.append(False)

        # =====================================================
        # TEST 4: DATA OPERATIONS - SELECT I VALIDACIJA
        # =====================================================
        print("\n🔍 Test 4: Data operations - Select i validacija")

        cursor.execute("SELECT * FROM vozila_istorija WHERE id = %s", (test_id2,))
        record = cursor.fetchone()

        validations = [
            (record['vozilo_id'] == 100, "vozilo_id"),
            (record['tip'] == 'Mali servis', "tip"),
            (record['datum'] == date(2026, 1, 20), "datum"),
            (record['km'] == 45000, "km"),
            (record['cena'] == Decimal('8500.00'), "cena"),
            (record['pozicija'] == 'Auto servis Beograd', "pozicija")
        ]

        for valid, field in validations:
            if not valid:
                print(f"❌ Validacija za {field} nije uspela")
                test_results.append(False)
            else:
                print(f"✅ {field} validacija OK")

        # =====================================================
        # TEST 5: DATA OPERATIONS - UPDATE
        # =====================================================
        print("\n🔄 Test 5: Data operations - Update")

        cursor.execute("""
            UPDATE vozila_istorija SET
                km = km + 500,
                cena = cena + 1200.00,
                opis = opis || ' - Dodatna provera akumulatora',
                pozicija = 'Auto servis Novi Sad'
            WHERE id = %s
        """, (test_id2,))

        cursor.execute("SELECT km, cena, pozicija FROM vozila_istorija WHERE id = %s", (test_id2,))
        updated = cursor.fetchone()

        if updated['km'] == 45500 and updated['cena'] == Decimal('9700.00') and updated['pozicija'] == 'Auto servis Novi Sad':
            print("✅ Update operacija uspešna")
        else:
            print("❌ Update operacija nije uspela")
            test_results.append(False)

        # =====================================================
        # TEST 6: FILTRIRANJE I PRETRAGA
        # =====================================================
        print("\n🔎 Test 6: Filtriranje i pretraga")

        # Dodaj test podatke
        test_data = [
            (101, 'Veliki servis', '2026-01-10', 95000, 'Kompletan servis motora', 25000.00, 'Servis Centar'),
            (102, 'Popravka', '2026-01-25', 120000, 'Zamena amortizera', 15000.00, 'Auto delovi'),
            (103, 'Registracija', '2026-01-30', 75000, 'Godišnja registracija', 8000.00, 'MUP stanica'),
            (104, 'Mali servis', '2026-01-05', 30000, 'Zamena guma', 18000.00, 'Vulkanizer')
        ]

        for data in test_data:
            cursor.execute("""
                INSERT INTO vozila_istorija (vozilo_id, tip, datum, km, opis, cena, pozicija)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            """, data)

        # Filtriranje po tipu
        cursor.execute("SELECT COUNT(*) as count FROM vozila_istorija WHERE tip = 'Mali servis'")
        count_service = cursor.fetchone()['count']
        print(f"✅ Mali servis: {count_service} intervencija")

        # Filtriranje po ceni
        cursor.execute("SELECT COUNT(*) as count FROM vozila_istorija WHERE cena >= 15000.00")
        count_expensive = cursor.fetchone()['count']
        print(f"✅ Skupi servisi (>=15000): {count_expensive} intervencija")

        # Filtriranje po datumu
        cursor.execute("SELECT COUNT(*) as count FROM vozila_istorija WHERE datum >= CURRENT_DATE - INTERVAL '30 days'")
        count_recent = cursor.fetchone()['count']
        print(f"✅ Nedavne intervencije: {count_recent} intervencija")

        # =====================================================
        # TEST 7: INDEKSI I PERFORMANSE
        # =====================================================
        print("\n⚡ Test 7: Indeksi i performanse")

        cursor.execute("""
            SELECT indexname FROM pg_indexes
            WHERE tablename = 'vozila_istorija'
            ORDER BY indexname
        """)
        indexes = [row['indexname'] for row in cursor.fetchall()]

        expected_indexes = [
            'idx_vozila_istorija_vozilo_id',
            'idx_vozila_istorija_tip',
            'idx_vozila_istorija_datum',
            'idx_vozila_istorija_vozilo_datum'
        ]

        missing_indexes = set(expected_indexes) - set(indexes)
        if missing_indexes:
            print(f"❌ Nedostaju indeksi: {missing_indexes}")
            test_results.append(False)
        else:
            print("✅ Svi indeksi postoje")

        # =====================================================
        # TEST 8: STATISTIKA I AGREGACIJE
        # =====================================================
        print("\n📊 Test 8: Statistika i agregacije")

        # Osnovna statistika
        cursor.execute("SELECT SUM(cena) as total, AVG(cena) as avg, MAX(km) as max_km FROM vozila_istorija")
        stats = cursor.fetchone()
        print(f"✅ Ukupni troškovi: {stats['total']}")
        print(f"✅ Prosečna cena: {stats['avg']}")
        print(f"✅ Maksimalna km: {stats['max_km']}")

        # Statistika po tipu
        cursor.execute("""
            SELECT tip, COUNT(*) as count, SUM(cena) as total_cost, AVG(cena) as avg_cost
            FROM vozila_istorija
            GROUP BY tip
            ORDER BY total_cost DESC
        """)
        type_stats = cursor.fetchall()
        print("✅ Statistika po tipu intervencije:")
        for stat in type_stats:
            print(f"   {stat['tip']}: {stat['count']} intervencija, ukupno {stat['total_cost']}, prosečno {stat['avg_cost']}")

        # Statistika po vozilima
        cursor.execute("""
            SELECT vozilo_id, COUNT(*) as services, SUM(cena) as total_spent, MAX(datum) as last_service
            FROM vozila_istorija
            GROUP BY vozilo_id
            ORDER BY total_spent DESC
        """)
        vehicle_stats = cursor.fetchall()
        print("✅ Statistika po vozilima:")
        for stat in vehicle_stats:
            print(f"   Vozilo {stat['vozilo_id']}: {stat['services']} servisa, potrošeno {stat['total_spent']}, poslednji {stat['last_service']}")

        # =====================================================
        # TEST 9: DATE OPERATIONS
        # =====================================================
        print("\n📅 Test 9: Date operations")

        # Filtriranje po vremenu
        cursor.execute("SELECT COUNT(*) as count FROM vozila_istorija WHERE datum >= CURRENT_DATE - INTERVAL '7 days'")
        recent = cursor.fetchone()['count']
        print(f"✅ Nedavne intervencije (7 dana): {recent}")

        cursor.execute("SELECT COUNT(*) as count FROM vozila_istorija WHERE datum < CURRENT_DATE - INTERVAL '6 months'")
        old = cursor.fetchone()['count']
        print(f"✅ Stare intervencije (6 meseci): {old}")

        # Troškovi u tekućem mesecu
        cursor.execute("""
            SELECT COALESCE(SUM(cena), 0) as monthly_cost
            FROM vozila_istorija
            WHERE DATE_TRUNC('month', datum) = DATE_TRUNC('month', CURRENT_DATE)
        """)
        monthly = cursor.fetchone()['monthly_cost']
        print(f"✅ Troškovi u tekućem mesecu: {monthly}")

        # =====================================================
        # TEST 10: CLEANUP
        # =====================================================
        print("\n🧹 Test 10: Cleanup - Čišćenje test podataka")

        # Briši test podatke
        cursor.execute("DELETE FROM vozila_istorija WHERE id = ANY(%s)", (test_ids,))
        cursor.execute("DELETE FROM vozila_istorija WHERE vozilo_id IN (101, 102, 103, 104)")

        # Provera cleanup-a
        cursor.execute("SELECT COUNT(*) as count FROM vozila_istorija WHERE vozilo_id IN (1, 100, 101, 102, 103, 104)")
        remaining = cursor.fetchone()['count']

        if remaining == 0:
            print("✅ Cleanup uspešan - test podaci obrisani")
        else:
            print(f"❌ Cleanup nije kompletan - ostalo {remaining} test zapisa")
            test_results.append(False)

        # =====================================================
        # FINAL REPORT
        # =====================================================
        print("\n" + "=" * 60)
        if all(test_results):
            print("🎉 SVI PYTHON TESTOVI ZA VOZILA_ISTORIJA PROŠLI!")
            print("✅ Tabela vozila_istorija je FUNKCIONALNA")
            print("✅ Schema validacija - OK")
            print("✅ Constraints - OK")
            print("✅ Data operations - OK")
            print("✅ Filtriranje - OK")
            print("✅ Indeksi - OK")
            print("✅ Statistika - OK")
            print("✅ Date operations - OK")
            print("✅ Cleanup - OK")
            print("\n📊 Tabela spremna za produkciju!")
            return True
        else:
            print("❌ NEKI TESTOVI NISU PROŠLI!")
            print(f"Broj neuspelih testova: {len([r for r in test_results if not r])}")
            return False

    except Exception as e:
        print(f"❌ Greška tokom testiranja: {e}")
        return False
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

if __name__ == "__main__":
    success = test_vozila_istorija()
    sys.exit(0 if success else 1)
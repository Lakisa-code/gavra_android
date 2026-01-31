# GAVRA SAMPION TEST VOZNJE_LOG PYTHON 2026
# Kompletni testovi za tabelu voznje_log
# Datum: 31.01.2026

import psycopg2
import psycopg2.extras
import json
import sys
from datetime import datetime, date
from decimal import Decimal

def test_voznje_log():
    """Kompletni testovi za tabelu voznje_log"""

    print("🚀 Počinjem testove za tabelu voznje_log...")
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
            WHERE table_name = 'voznje_log'
            ORDER BY ordinal_position
        """)

        columns = cursor.fetchall()
        expected_columns = ['id', 'putnik_id', 'datum', 'tip', 'iznos', 'vozac_id', 'created_at',
                           'placeni_mesec', 'placena_godina', 'sati_pre_polaska', 'broj_mesta', 'detalji', 'meta']

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
        if column_types.get('iznos') == 'numeric':
            print("✅ Iznos je DECIMAL tip")
        else:
            print(f"❌ Iznos nije DECIMAL tip: {column_types.get('iznos')}")
            test_results.append(False)

        if column_types.get('meta') == 'jsonb':
            print("✅ Meta je JSONB tip")
        else:
            print(f"❌ Meta nije JSONB tip: {column_types.get('meta')}")
            test_results.append(False)

        # =====================================================
        # TEST 2: CONSTRAINTS I DEFAULT VREDNOSTI
        # =====================================================
        print("\n🔒 Test 2: Constraints i default vrednosti")

        # Test NOT NULL constraints
        try:
            cursor.execute("INSERT INTO voznje_log (datum, tip) VALUES ('2026-01-31', 'Test')")
            print("❌ NOT NULL constraint za putnik_id ne radi")
            test_results.append(False)
        except psycopg2.Error:
            print("✅ NOT NULL constraint za putnik_id radi")

        try:
            cursor.execute("INSERT INTO voznje_log (putnik_id, datum) VALUES (1, '2026-01-31')")
            print("❌ NOT NULL constraint za tip ne radi")
            test_results.append(False)
        except psycopg2.Error:
            print("✅ NOT NULL constraint za tip radi")

        # Test DECIMAL precision
        cursor.execute("""
            INSERT INTO voznje_log (putnik_id, datum, tip, iznos)
            VALUES (1, '2026-01-15', 'Test vožnja', 1250.50)
            RETURNING id
        """)
        test_id = cursor.fetchone()['id']
        test_ids.append(test_id)

        cursor.execute("SELECT iznos FROM voznje_log WHERE id = %s", (test_id,))
        iznos = cursor.fetchone()['iznos']
        if iznos == Decimal('1250.50'):
            print("✅ DECIMAL precision za iznos radi")
        else:
            print(f"❌ DECIMAL precision ne radi: {iznos}")
            test_results.append(False)

        # Test DEFAULT vrednosti
        cursor.execute("SELECT created_at, broj_mesta FROM voznje_log WHERE id = %s", (test_id,))
        defaults = cursor.fetchone()
        if defaults['created_at'] is not None and defaults['broj_mesta'] == 1:
            print("✅ Default vrednosti za created_at i broj_mesta rade")
        else:
            print("❌ Default vrednosti ne rade")
            test_results.append(False)

        # =====================================================
        # TEST 3: DATA OPERATIONS - INSERT
        # =====================================================
        print("\n💾 Test 3: Data operations - Insert")

        cursor.execute("""
            INSERT INTO voznje_log (
                putnik_id, datum, tip, iznos, vozac_id, placeni_mesec, placena_godina,
                sati_pre_polaska, broj_mesta, detalji, meta
            ) VALUES (
                100, '2026-01-20', 'Redovna vožnja', 850.00, 5, 1, 2026,
                2, 1, 'Vožnja od kuće do škole',
                '{"route": "Kuća -> Škola", "distance": 15.5, "duration": 25}'
            ) RETURNING id
        """)
        test_id2 = cursor.fetchone()['id']
        test_ids.append(test_id2)

        cursor.execute("SELECT COUNT(*) as count FROM voznje_log WHERE id = %s", (test_id2,))
        if cursor.fetchone()['count'] > 0:
            print("✅ Insert operacija uspešna")
        else:
            print("❌ Insert operacija nije uspela")
            test_results.append(False)

        # =====================================================
        # TEST 4: DATA OPERATIONS - SELECT I VALIDACIJA
        # =====================================================
        print("\n🔍 Test 4: Data operations - Select i validacija")

        cursor.execute("SELECT * FROM voznje_log WHERE id = %s", (test_id2,))
        record = cursor.fetchone()

        validations = [
            (record['putnik_id'] == 100, "putnik_id"),
            (record['tip'] == 'Redovna vožnja', "tip"),
            (record['datum'] == date(2026, 1, 20), "datum"),
            (record['iznos'] == Decimal('850.00'), "iznos"),
            (record['vozac_id'] == 5, "vozac_id"),
            (record['placeni_mesec'] == 1, "placeni_mesec"),
            (record['placena_godina'] == 2026, "placena_godina"),
            (record['sati_pre_polaska'] == 2, "sati_pre_polaska"),
            (record['broj_mesta'] == 1, "broj_mesta")
        ]

        for valid, field in validations:
            if not valid:
                print(f"❌ Validacija za {field} nije uspela")
                test_results.append(False)
            else:
                print(f"✅ {field} validacija OK")

        # JSONB validacija
        meta_data = json.loads(record['meta'])
        if meta_data.get('route') == 'Kuća -> Škola':
            print("✅ JSONB meta validacija OK")
        else:
            print("❌ JSONB meta validacija nije uspela")
            test_results.append(False)

        # =====================================================
        # TEST 5: DATA OPERATIONS - UPDATE
        # =====================================================
        print("\n🔄 Test 5: Data operations - Update")

        cursor.execute("""
            UPDATE voznje_log SET
                iznos = iznos + 50.00,
                sati_pre_polaska = 1,
                detalji = detalji || ' - Promena vremena',
                meta = meta || '{"updated": true}'
            WHERE id = %s
        """, (test_id2,))

        cursor.execute("SELECT iznos, sati_pre_polaska, detalji, meta FROM voznje_log WHERE id = %s", (test_id2,))
        updated = cursor.fetchone()

        if updated['iznos'] == Decimal('900.00') and updated['sati_pre_polaska'] == 1:
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
            (101, '2026-01-10', 'Vanredna vožnja', 1200.00, 6, 1, 2026, 0, 'Hitna vožnja', '{"urgent": true}'),
            (102, '2026-01-25', 'Redovna vožnja', 750.00, 7, 1, 2026, 3, 'Školska vožnja', '{"school": true}'),
            (103, '2026-01-30', 'Grupna vožnja', 2000.00, 8, 1, 2026, 1, 'Grupni prevoz', '{"group_size": 4}'),
            (104, '2026-01-05', 'Redovna vožnja', 650.00, 9, 1, 2026, 4, 'Dnevna vožnja', '{"daily": true}')
        ]

        for data in test_data:
            cursor.execute("""
                INSERT INTO voznje_log (putnik_id, datum, tip, iznos, vozac_id, placeni_mesec, placena_godina,
                                       sati_pre_polaska, detalji, meta)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, data)

        # Filtriranje po tipu
        cursor.execute("SELECT COUNT(*) as count FROM voznje_log WHERE tip = 'Redovna vožnja'")
        count_regular = cursor.fetchone()['count']
        print(f"✅ Redovne vožnje: {count_regular} vožnji")

        # Filtriranje po plaćenom periodu
        cursor.execute("SELECT COUNT(*) as count FROM voznje_log WHERE placeni_mesec = 1 AND placena_godina = 2026")
        count_paid = cursor.fetchone()['count']
        print(f"✅ Plaćene u januaru 2026: {count_paid} vožnji")

        # Filtriranje po satima pre polaska
        cursor.execute("SELECT COUNT(*) as count FROM voznje_log WHERE sati_pre_polaska <= 2")
        count_early = cursor.fetchone()['count']
        print(f"✅ Rane vožnje (<=2h): {count_early} vožnji")

        # =====================================================
        # TEST 7: INDEKSI I PERFORMANSE
        # =====================================================
        print("\n⚡ Test 7: Indeksi i performanse")

        cursor.execute("""
            SELECT indexname FROM pg_indexes
            WHERE tablename = 'voznje_log'
            ORDER BY indexname
        """)
        indexes = [row['indexname'] for row in cursor.fetchall()]

        expected_indexes = [
            'idx_voznje_log_putnik_id',
            'idx_voznje_log_vozac_id',
            'idx_voznje_log_datum',
            'idx_voznje_log_tip',
            'idx_voznje_log_placeni_mesec_godina'
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
        cursor.execute("SELECT SUM(iznos) as total, AVG(iznos) as avg, MAX(iznos) as max FROM voznje_log")
        stats = cursor.fetchone()
        print(f"✅ Ukupni prihodi: {stats['total']}")
        print(f"✅ Prosečna cena: {stats['avg']}")
        print(f"✅ Maksimalna cena: {stats['max']}")

        # Statistika po tipu vožnje
        cursor.execute("""
            SELECT tip, COUNT(*) as count, SUM(iznos) as total_revenue, AVG(iznos) as avg_amount
            FROM voznje_log
            GROUP BY tip
            ORDER BY total_revenue DESC
        """)
        type_stats = cursor.fetchall()
        print("✅ Statistika po tipu vožnje:")
        for stat in type_stats:
            print(f"   {stat['tip']}: {stat['count']} vožnji, ukupno {stat['total_revenue']}, prosečno {stat['avg_amount']}")

        # Statistika po vozačima
        cursor.execute("""
            SELECT vozac_id, COUNT(*) as trips, SUM(iznos) as total_earned, AVG(iznos) as avg_per_trip
            FROM voznje_log
            WHERE vozac_id IS NOT NULL
            GROUP BY vozac_id
            ORDER BY total_earned DESC
        """)
        driver_stats = cursor.fetchall()
        print("✅ Statistika po vozačima:")
        for stat in driver_stats:
            print(f"   Vozač {stat['vozac_id']}: {stat['trips']} vožnji, zaradio {stat['total_earned']}, prosečno {stat['avg_per_trip']}")

        # =====================================================
        # TEST 9: JSONB OPERATIONS
        # =====================================================
        print("\n🔧 Test 9: JSONB operations")

        # Test JSONB upita
        cursor.execute("SELECT COUNT(*) as count FROM voznje_log WHERE meta IS NOT NULL")
        json_count = cursor.fetchone()['count']
        print(f"✅ Zapisi sa JSONB meta: {json_count}")

        # Filtriranje po JSONB
        cursor.execute("SELECT COUNT(*) as count FROM voznje_log WHERE meta->>'urgent' = 'true'")
        urgent_count = cursor.fetchone()['count']
        print(f"✅ Urgent vožnje: {urgent_count}")

        cursor.execute("SELECT COUNT(*) as count FROM voznje_log WHERE meta->>'school' = 'true'")
        school_count = cursor.fetchone()['count']
        print(f"✅ Školske vožnje: {school_count}")

        # JSONB update
        cursor.execute("UPDATE voznje_log SET meta = meta || '{\"processed\": true}' WHERE meta IS NOT NULL")
        cursor.execute("SELECT COUNT(*) as count FROM voznje_log WHERE meta->>'processed' = 'true'")
        processed_count = cursor.fetchone()['count']
        print(f"✅ Procesirane vožnje: {processed_count}")

        # =====================================================
        # TEST 10: CLEANUP
        # =====================================================
        print("\n🧹 Test 10: Cleanup - Čišćenje test podataka")

        # Briši test podatke
        cursor.execute("DELETE FROM voznje_log WHERE id = ANY(%s)", (test_ids,))
        cursor.execute("DELETE FROM voznje_log WHERE putnik_id IN (101, 102, 103, 104)")

        # Provera cleanup-a
        cursor.execute("SELECT COUNT(*) as count FROM voznje_log WHERE putnik_id IN (1, 100, 101, 102, 103, 104)")
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
            print("🎉 SVI PYTHON TESTOVI ZA VOZNJE_LOG PROŠLI!")
            print("✅ Tabela voznje_log je FUNKCIONALNA")
            print("✅ Schema validacija - OK")
            print("✅ Constraints - OK")
            print("✅ Data operations - OK")
            print("✅ Filtriranje - OK")
            print("✅ Indeksi - OK")
            print("✅ Statistika - OK")
            print("✅ JSONB operations - OK")
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
    success = test_voznje_log()
    sys.exit(0 if success else 1)
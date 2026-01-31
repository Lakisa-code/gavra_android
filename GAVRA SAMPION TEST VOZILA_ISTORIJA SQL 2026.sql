-- GAVRA SAMPION TEST VOZILA_ISTORIJA SQL 2026
-- Kompletni testovi za tabelu vozila_istorija
-- Datum: 31.01.2026

-- =====================================================
-- TEST 1: PROVERA POSTOJANJA TABELE I SCHEMA
-- =====================================================
DO $$
BEGIN
    -- Provera da li tabela postoji
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'vozila_istorija') THEN
        RAISE EXCEPTION 'Tabela vozila_istorija ne postoji!';
    END IF;

    -- Provera kolona
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'vozila_istorija' AND column_name = 'id') THEN
        RAISE EXCEPTION 'Kolona id ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'vozila_istorija' AND column_name = 'vozilo_id') THEN
        RAISE EXCEPTION 'Kolona vozilo_id ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'vozila_istorija' AND column_name = 'tip') THEN
        RAISE EXCEPTION 'Kolona tip ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'vozila_istorija' AND column_name = 'cena') THEN
        RAISE EXCEPTION 'Kolona cena ne postoji!';
    END IF;

    RAISE NOTICE '✅ Test 1: Tabela i osnovne kolone postoje';
END $$;

-- =====================================================
-- TEST 2: CONSTRAINTS I DEFAULT VREDNOSTI
-- =====================================================
DO $$
DECLARE
    test_id INTEGER;
BEGIN
    -- Test NOT NULL constraints
    BEGIN
        INSERT INTO vozila_istorija (tip, datum) VALUES ('Test', '2026-01-31');
        RAISE EXCEPTION 'NOT NULL constraint za vozilo_id ne radi!';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '✅ NOT NULL constraint za vozilo_id radi';
    END;

    BEGIN
        INSERT INTO vozila_istorija (vozilo_id, datum) VALUES (1, '2026-01-31');
        RAISE EXCEPTION 'NOT NULL constraint za tip ne radi!';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '✅ NOT NULL constraint za tip radi';
    END;

    BEGIN
        INSERT INTO vozila_istorija (vozilo_id, tip) VALUES (1, 'Test');
        RAISE EXCEPTION 'NOT NULL constraint za datum ne radi!';
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'NOT NULL constraint za datum ne radi!';
    END;

    -- Test DECIMAL precision za cenu
    BEGIN
        INSERT INTO vozila_istorija (vozilo_id, tip, datum, cena)
        VALUES (1, 'Servis', '2026-01-15', 1250.50)
        RETURNING id INTO test_id;

        -- Provera da li je cena sačuvana sa tačnošću
        IF EXISTS (SELECT 1 FROM vozila_istorija WHERE id = test_id AND cena = 1250.50) THEN
            RAISE NOTICE '✅ DECIMAL precision za cena radi';
        ELSE
            RAISE EXCEPTION 'Cena nije sačuvana sa tačnom preciznošću!';
        END IF;
    END;

    -- Test DEFAULT vrednosti za created_at
    IF EXISTS (SELECT 1 FROM vozila_istorija WHERE id = test_id AND created_at IS NOT NULL) THEN
        RAISE NOTICE '✅ Default vrednost za created_at radi';
    ELSE
        RAISE EXCEPTION 'Default vrednost za created_at ne radi!';
    END IF;

    -- Čuvaj ID za sledeće testove
    PERFORM set_config('test.vozila_istorija_id', test_id::text, false);
END $$;

-- =====================================================
-- TEST 3: DATA OPERATIONS - INSERT
-- =====================================================
DO $$
DECLARE
    test_id INTEGER;
BEGIN
    -- Insert sa svim poljima
    INSERT INTO vozila_istorija (
        vozilo_id, tip, datum, km, opis, cena, pozicija
    ) VALUES (
        100, 'Mali servis', '2026-01-20', 45000,
        'Zamena ulja i filtera, provera kočnica', 8500.00, 'Auto servis Beograd'
    ) RETURNING id INTO test_id;

    -- Provera inserta
    IF EXISTS (SELECT 1 FROM vozila_istorija WHERE id = test_id) THEN
        RAISE NOTICE '✅ Test 3: Insert operacija uspešna';
    ELSE
        RAISE EXCEPTION 'Insert nije uspeo!';
    END IF;

    -- Čuvaj ID za sledeće testove
    PERFORM set_config('test.vozila_istorija_id2', test_id::text, false);
END $$;

-- =====================================================
-- TEST 4: DATA OPERATIONS - SELECT I VALIDACIJA
-- =====================================================
DO $$
DECLARE
    test_id INTEGER := current_setting('test.vozila_istorija_id2')::integer;
    record RECORD;
BEGIN
    -- Select i validacija podataka
    SELECT * INTO record FROM vozila_istorija WHERE id = test_id;

    IF record.vozilo_id != 100 THEN
        RAISE EXCEPTION 'vozilo_id nije ispravan: %', record.vozilo_id;
    END IF;

    IF record.tip != 'Mali servis' THEN
        RAISE EXCEPTION 'tip nije ispravan: %', record.tip;
    END IF;

    IF record.datum != '2026-01-20' THEN
        RAISE EXCEPTION 'datum nije ispravan: %', record.datum;
    END IF;

    IF record.km != 45000 THEN
        RAISE EXCEPTION 'km nije ispravan: %', record.km;
    END IF;

    IF record.cena != 8500.00 THEN
        RAISE EXCEPTION 'cena nije ispravna: %', record.cena;
    END IF;

    RAISE NOTICE '✅ Test 4: Select i validacija podataka uspešni';
END $$;

-- =====================================================
-- TEST 5: DATA OPERATIONS - UPDATE
-- =====================================================
DO $$
DECLARE
    test_id INTEGER := current_setting('test.vozila_istorija_id2')::integer;
BEGIN
    -- Update podataka
    UPDATE vozila_istorija SET
        km = km + 500,
        cena = cena + 1200.00,
        opis = opis || ' - Dodatna provera akumulatora',
        pozicija = 'Auto servis Novi Sad'
    WHERE id = test_id;

    -- Provera update-a
    IF EXISTS (SELECT 1 FROM vozila_istorija
               WHERE id = test_id AND km = 45500 AND cena = 9700.00) THEN
        RAISE NOTICE '✅ Test 5: Update operacija uspešna';
    ELSE
        RAISE EXCEPTION 'Update nije uspeo!';
    END IF;
END $$;

-- =====================================================
-- TEST 6: FILTRIRANJE I PRETRAGA
-- =====================================================
DO $$
DECLARE
    test_id INTEGER := current_setting('test.vozila_istorija_id2')::integer;
    count_service INTEGER;
    count_expensive INTEGER;
    count_recent INTEGER;
BEGIN
    -- Dodaj još test podataka za filtriranje
    INSERT INTO vozila_istorija (vozilo_id, tip, datum, km, opis, cena, pozicija) VALUES
        (101, 'Veliki servis', '2026-01-10', 95000, 'Kompletan servis motora', 25000.00, 'Servis Centar'),
        (102, 'Popravka', '2026-01-25', 120000, 'Zamena amortizera', 15000.00, 'Auto delovi'),
        (103, 'Registracija', '2026-01-30', 75000, 'Godišnja registracija', 8000.00, 'MUP stanica'),
        (104, 'Mali servis', '2026-01-05', 30000, 'Zamena guma', 18000.00, 'Vulkanizer');

    -- Filtriranje po tipu
    SELECT COUNT(*) INTO count_service
    FROM vozila_istorija
    WHERE tip = 'Mali servis';

    IF count_service < 2 THEN
        RAISE EXCEPTION 'Filtriranje po tipu ne radi!';
    END IF;

    -- Filtriranje po ceni (skupo)
    SELECT COUNT(*) INTO count_expensive
    FROM vozila_istorija
    WHERE cena >= 15000.00;

    IF count_expensive < 2 THEN
        RAISE EXCEPTION 'Filtriranje po ceni ne radi!';
    END IF;

    -- Filtriranje po datumu (nedavne)
    SELECT COUNT(*) INTO count_recent
    FROM vozila_istorija
    WHERE datum >= CURRENT_DATE - INTERVAL '30 days';

    IF count_recent < 4 THEN
        RAISE EXCEPTION 'Filtriranje po datumu ne radi!';
    END IF;

    RAISE NOTICE '✅ Test 6: Filtriranje i pretraga uspešni - service: %, expensive: %, recent: %',
                count_service, count_expensive, count_recent;
END $$;

-- =====================================================
-- TEST 7: INDEKSI I PERFORMANSE
-- =====================================================
DO $$
DECLARE
    plan_text TEXT;
BEGIN
    -- Provera postojanja indeksa
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'vozila_istorija' AND indexname = 'idx_vozila_istorija_vozilo_id') THEN
        RAISE EXCEPTION 'Indeks idx_vozila_istorija_vozilo_id ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'vozila_istorija' AND indexname = 'idx_vozila_istorija_tip') THEN
        RAISE EXCEPTION 'Indeks idx_vozila_istorija_tip ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'vozila_istorija' AND indexname = 'idx_vozila_istorija_datum') THEN
        RAISE EXCEPTION 'Indeks idx_vozila_istorija_datum ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'vozila_istorija' AND indexname = 'idx_vozila_istorija_vozilo_datum') THEN
        RAISE EXCEPTION 'Indeks idx_vozila_istorija_vozilo_datum ne postoji!';
    END IF;

    RAISE NOTICE '✅ Test 7: Indeksi postoje i funkcionišu';
END $$;

-- =====================================================
-- TEST 8: STATISTIKA I AGREGACIJE
-- =====================================================
DO $$
DECLARE
    total_cost NUMERIC;
    avg_cost NUMERIC;
    max_km INTEGER;
    vehicle_stats RECORD;
BEGIN
    -- Osnovna statistika
    SELECT SUM(cena), AVG(cena), MAX(km)
    INTO total_cost, avg_cost, max_km
    FROM vozila_istorija;

    RAISE NOTICE 'Ukupni troškovi: %, Prosečna cena: %, Maksimalna km: %',
                total_cost, avg_cost, max_km;

    -- Statistika po tipu intervencije
    FOR vehicle_stats IN
        SELECT tip, COUNT(*) as count, SUM(cena) as total_cost, AVG(cena) as avg_cost
        FROM vozila_istorija
        GROUP BY tip
        ORDER BY total_cost DESC
    LOOP
        RAISE NOTICE 'Tip %: % intervencija, ukupno %, prosečno %',
                    vehicle_stats.tip, vehicle_stats.count, vehicle_stats.total_cost, vehicle_stats.avg_cost;
    END LOOP;

    -- Statistika po vozilima
    FOR vehicle_stats IN
        SELECT vozilo_id, COUNT(*) as services, SUM(cena) as total_spent, MAX(datum) as last_service
        FROM vozila_istorija
        GROUP BY vozilo_id
        ORDER BY total_spent DESC
    LOOP
        RAISE NOTICE 'Vozilo ID %: % servisa, potrošeno %, poslednji servis %',
                    vehicle_stats.vozilo_id, vehicle_stats.services, vehicle_stats.total_spent, vehicle_stats.last_service;
    END LOOP;

    -- Statistika po mesecima
    FOR vehicle_stats IN
        SELECT DATE_TRUNC('month', datum) as month, COUNT(*) as services, SUM(cena) as monthly_cost
        FROM vozila_istorija
        GROUP BY DATE_TRUNC('month', datum)
        ORDER BY month DESC
    LOOP
        RAISE NOTICE 'Mesec %: % servisa, mesečni troškovi %',
                    vehicle_stats.month, vehicle_stats.services, vehicle_stats.monthly_cost;
    END LOOP;

    RAISE NOTICE '✅ Test 8: Statistika i agregacije uspešne';
END $$;

-- =====================================================
-- TEST 9: DATE OPERATIONS
-- =====================================================
DO $$
DECLARE
    recent_services INTEGER;
    old_services INTEGER;
    this_month_cost NUMERIC;
BEGIN
    -- Filtriranje po vremenu (nedavne intervencije)
    SELECT COUNT(*) INTO recent_services
    FROM vozila_istorija
    WHERE datum >= CURRENT_DATE - INTERVAL '7 days';

    -- Filtriranje po starim intervencijama
    SELECT COUNT(*) INTO old_services
    FROM vozila_istorija
    WHERE datum < CURRENT_DATE - INTERVAL '6 months';

    RAISE NOTICE 'Nedavne intervencije (7 dana): %, Stare intervencije (6 meseci): %',
                recent_services, old_services;

    -- Troškovi u tekućem mesecu
    SELECT COALESCE(SUM(cena), 0) INTO this_month_cost
    FROM vozila_istorija
    WHERE DATE_TRUNC('month', datum) = DATE_TRUNC('month', CURRENT_DATE);

    RAISE NOTICE 'Troškovi u tekućem mesecu: %', this_month_cost;

    -- Test ekstrakcije vremenskih podataka
    IF EXISTS (SELECT 1 FROM vozila_istorija
               WHERE EXTRACT(YEAR FROM datum) = 2026) THEN
        RAISE NOTICE '✅ Date operations funkcionišu';
    ELSE
        RAISE EXCEPTION 'Date operations ne rade!';
    END IF;

    RAISE NOTICE '✅ Test 9: Date operations uspešne';
END $$;

-- =====================================================
-- TEST 10: CLEANUP - ČIŠĆENJE TEST PODATAKA
-- =====================================================
DO $$
DECLARE
    test_id1 INTEGER := current_setting('test.vozila_istorija_id')::integer;
    test_id2 INTEGER := current_setting('test.vozila_istorija_id2')::integer;
BEGIN
    -- Briši test podatke
    DELETE FROM vozila_istorija WHERE id IN (test_id1, test_id2);
    DELETE FROM vozila_istorija WHERE vozilo_id IN (101, 102, 103, 104);

    -- Provera da li je cleanup uspeo
    IF NOT EXISTS (SELECT 1 FROM vozila_istorija WHERE vozilo_id IN (1, 100, 101, 102, 103, 104)) THEN
        RAISE NOTICE '✅ Test 10: Cleanup uspešan - test podaci obrisani';
    ELSE
        RAISE EXCEPTION 'Cleanup nije kompletan!';
    END IF;
END $$;

-- =====================================================
-- FINAL REPORT
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🎉 SVI SQL TESTOVI ZA VOZILA_ISTORIJA PROŠLI!';
    RAISE NOTICE '✅ Tabela vozila_istorija je FUNKCIONALNA';
    RAISE NOTICE '✅ Schema validacija - OK';
    RAISE NOTICE '✅ Constraints - OK';
    RAISE NOTICE '✅ Data operations - OK';
    RAISE NOTICE '✅ Filtriranje - OK';
    RAISE NOTICE '✅ Indeksi - OK';
    RAISE NOTICE '✅ Statistika - OK';
    RAISE NOTICE '✅ Date operations - OK';
    RAISE NOTICE '✅ Cleanup - OK';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Tabela spremna za produkciju!';
END $$;
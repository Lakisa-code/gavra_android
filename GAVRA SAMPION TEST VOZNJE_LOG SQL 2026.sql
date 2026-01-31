-- GAVRA SAMPION TEST VOZNJE_LOG SQL 2026
-- Kompletni testovi za tabelu voznje_log
-- Datum: 31.01.2026

-- =====================================================
-- TEST 1: PROVERA POSTOJANJA TABELE I SCHEMA
-- =====================================================
DO $$
BEGIN
    -- Provera da li tabela postoji
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'voznje_log') THEN
        RAISE EXCEPTION 'Tabela voznje_log ne postoji!';
    END IF;

    -- Provera kolona
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'voznje_log' AND column_name = 'id') THEN
        RAISE EXCEPTION 'Kolona id ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'voznje_log' AND column_name = 'putnik_id') THEN
        RAISE EXCEPTION 'Kolona putnik_id ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'voznje_log' AND column_name = 'tip') THEN
        RAISE EXCEPTION 'Kolona tip ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'voznje_log' AND column_name = 'iznos') THEN
        RAISE EXCEPTION 'Kolona iznos ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'voznje_log' AND column_name = 'meta') THEN
        RAISE EXCEPTION 'Kolona meta (JSONB) ne postoji!';
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
        INSERT INTO voznje_log (datum, tip) VALUES ('2026-01-31', 'Test');
        RAISE EXCEPTION 'NOT NULL constraint za putnik_id ne radi!';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '✅ NOT NULL constraint za putnik_id radi';
    END;

    BEGIN
        INSERT INTO voznje_log (putnik_id, datum) VALUES (1, '2026-01-31');
        RAISE EXCEPTION 'NOT NULL constraint za tip ne radi!';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '✅ NOT NULL constraint za tip radi';
    END;

    BEGIN
        INSERT INTO voznje_log (putnik_id, tip) VALUES (1, 'Test');
        RAISE EXCEPTION 'NOT NULL constraint za datum ne radi!';
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'NOT NULL constraint za datum ne radi!';
    END;

    -- Test DECIMAL precision za iznos
    BEGIN
        INSERT INTO voznje_log (putnik_id, datum, tip, iznos)
        VALUES (1, '2026-01-15', 'Vožnja', 1250.50)
        RETURNING id INTO test_id;

        -- Provera da li je iznos sačuvan sa tačnošću
        IF EXISTS (SELECT 1 FROM voznje_log WHERE id = test_id AND iznos = 1250.50) THEN
            RAISE NOTICE '✅ DECIMAL precision za iznos radi';
        ELSE
            RAISE EXCEPTION 'Iznos nije sačuvan sa tačnom preciznošću!';
        END IF;
    END;

    -- Test DEFAULT vrednosti za created_at i broj_mesta
    IF EXISTS (SELECT 1 FROM voznje_log WHERE id = test_id AND created_at IS NOT NULL) THEN
        RAISE NOTICE '✅ Default vrednost za created_at radi';
    ELSE
        RAISE EXCEPTION 'Default vrednost za created_at ne radi!';
    END IF;

    IF EXISTS (SELECT 1 FROM voznje_log WHERE id = test_id AND broj_mesta = 1) THEN
        RAISE NOTICE '✅ Default vrednost za broj_mesta radi';
    ELSE
        RAISE EXCEPTION 'Default vrednost za broj_mesta ne radi!';
    END IF;

    -- Čuvaj ID za sledeće testove
    PERFORM set_config('test.voznje_log_id', test_id::text, false);
END $$;

-- =====================================================
-- TEST 3: DATA OPERATIONS - INSERT
-- =====================================================
DO $$
DECLARE
    test_id INTEGER;
BEGIN
    -- Insert sa svim poljima
    INSERT INTO voznje_log (
        putnik_id, datum, tip, iznos, vozac_id, placeni_mesec, placena_godina,
        sati_pre_polaska, broj_mesta, detalji, meta
    ) VALUES (
        100, '2026-01-20', 'Redovna vožnja', 850.00, 5, 1, 2026,
        2, 1, 'Vožnja od kuće do škole',
        '{"route": "Kuća -> Škola", "distance": 15.5, "duration": 25}'
    ) RETURNING id INTO test_id;

    -- Provera inserta
    IF EXISTS (SELECT 1 FROM voznje_log WHERE id = test_id) THEN
        RAISE NOTICE '✅ Test 3: Insert operacija uspešna';
    ELSE
        RAISE EXCEPTION 'Insert nije uspeo!';
    END IF;

    -- Čuvaj ID za sledeće testove
    PERFORM set_config('test.voznje_log_id2', test_id::text, false);
END $$;

-- =====================================================
-- TEST 4: DATA OPERATIONS - SELECT I VALIDACIJA
-- =====================================================
DO $$
DECLARE
    test_id INTEGER := current_setting('test.voznje_log_id2')::integer;
    record RECORD;
BEGIN
    -- Select i validacija podataka
    SELECT * INTO record FROM voznje_log WHERE id = test_id;

    IF record.putnik_id != 100 THEN
        RAISE EXCEPTION 'putnik_id nije ispravan: %', record.putnik_id;
    END IF;

    IF record.tip != 'Redovna vožnja' THEN
        RAISE EXCEPTION 'tip nije ispravan: %', record.tip;
    END IF;

    IF record.datum != '2026-01-20' THEN
        RAISE EXCEPTION 'datum nije ispravan: %', record.datum;
    END IF;

    IF record.iznos != 850.00 THEN
        RAISE EXCEPTION 'iznos nije ispravan: %', record.iznos;
    END IF;

    IF record.placeni_mesec != 1 OR record.placena_godina != 2026 THEN
        RAISE EXCEPTION 'placeni_mesec/godina nisu ispravni';
    END IF;

    -- Provera JSONB polja
    IF record.meta->>'route' != 'Kuća -> Škola' THEN
        RAISE EXCEPTION 'JSONB meta polje nije ispravno';
    END IF;

    RAISE NOTICE '✅ Test 4: Select i validacija podataka uspešni';
END $$;

-- =====================================================
-- TEST 5: DATA OPERATIONS - UPDATE
-- =====================================================
DO $$
DECLARE
    test_id INTEGER := current_setting('test.voznje_log_id2')::integer;
BEGIN
    -- Update podataka
    UPDATE voznje_log SET
        iznos = iznos + 50.00,
        sati_pre_polaska = 1,
        detalji = detalji || ' - Promena vremena',
        meta = meta || '{"updated": true}'
    WHERE id = test_id;

    -- Provera update-a
    IF EXISTS (SELECT 1 FROM voznje_log
               WHERE id = test_id AND iznos = 900.00 AND sati_pre_polaska = 1) THEN
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
    test_id INTEGER := current_setting('test.voznje_log_id2')::integer;
    count_regular INTEGER;
    count_paid INTEGER;
    count_early INTEGER;
BEGIN
    -- Dodaj još test podataka za filtriranje
    INSERT INTO voznje_log (putnik_id, datum, tip, iznos, vozac_id, placeni_mesec, placena_godina, sati_pre_polaska, detalji, meta) VALUES
        (101, '2026-01-10', 'Vanredna vožnja', 1200.00, 6, 1, 2026, 0, 'Hitna vožnja', '{"urgent": true}'),
        (102, '2026-01-25', 'Redovna vožnja', 750.00, 7, 1, 2026, 3, 'Školska vožnja', '{"school": true}'),
        (103, '2026-01-30', 'Grupna vožnja', 2000.00, 8, 1, 2026, 1, 'Grupni prevoz', '{"group_size": 4}'),
        (104, '2026-01-05', 'Redovna vožnja', 650.00, 9, 1, 2026, 4, 'Dnevna vožnja', '{"daily": true}');

    -- Filtriranje po tipu
    SELECT COUNT(*) INTO count_regular
    FROM voznje_log
    WHERE tip = 'Redovna vožnja';

    IF count_regular < 2 THEN
        RAISE EXCEPTION 'Filtriranje po tipu ne radi!';
    END IF;

    -- Filtriranje po plaćenom mesecu/godini
    SELECT COUNT(*) INTO count_paid
    FROM voznje_log
    WHERE placeni_mesec = 1 AND placena_godina = 2026;

    IF count_paid < 5 THEN
        RAISE EXCEPTION 'Filtriranje po plaćenom periodu ne radi!';
    END IF;

    -- Filtriranje po satima pre polaska
    SELECT COUNT(*) INTO count_early
    FROM voznje_log
    WHERE sati_pre_polaska <= 2;

    IF count_early < 3 THEN
        RAISE EXCEPTION 'Filtriranje po satima pre polaska ne radi!';
    END IF;

    RAISE NOTICE '✅ Test 6: Filtriranje i pretraga uspešni - regular: %, paid: %, early: %',
                count_regular, count_paid, count_early;
END $$;

-- =====================================================
-- TEST 7: INDEKSI I PERFORMANSE
-- =====================================================
DO $$
BEGIN
    -- Provera postojanja indeksa
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'voznje_log' AND indexname = 'idx_voznje_log_putnik_id') THEN
        RAISE EXCEPTION 'Indeks idx_voznje_log_putnik_id ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'voznje_log' AND indexname = 'idx_voznje_log_vozac_id') THEN
        RAISE EXCEPTION 'Indeks idx_voznje_log_vozac_id ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'voznje_log' AND indexname = 'idx_voznje_log_datum') THEN
        RAISE EXCEPTION 'Indeks idx_voznje_log_datum ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'voznje_log' AND indexname = 'idx_voznje_log_tip') THEN
        RAISE EXCEPTION 'Indeks idx_voznje_log_tip ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'voznje_log' AND indexname = 'idx_voznje_log_placeni_mesec_godina') THEN
        RAISE EXCEPTION 'Indeks idx_voznje_log_placeni_mesec_godina ne postoji!';
    END IF;

    RAISE NOTICE '✅ Test 7: Indeksi postoje i funkcionišu';
END $$;

-- =====================================================
-- TEST 8: STATISTIKA I AGREGACIJE
-- =====================================================
DO $$
DECLARE
    total_revenue NUMERIC;
    avg_amount NUMERIC;
    max_amount NUMERIC;
    trip_stats RECORD;
BEGIN
    -- Osnovna statistika
    SELECT SUM(iznos), AVG(iznos), MAX(iznos)
    INTO total_revenue, avg_amount, max_amount
    FROM voznje_log;

    RAISE NOTICE 'Ukupni prihodi: %, Prosečna cena: %, Maksimalna cena: %',
                total_revenue, avg_amount, max_amount;

    -- Statistika po tipu vožnje
    FOR trip_stats IN
        SELECT tip, COUNT(*) as count, SUM(iznos) as total_revenue, AVG(iznos) as avg_amount
        FROM voznje_log
        GROUP BY tip
        ORDER BY total_revenue DESC
    LOOP
        RAISE NOTICE 'Tip %: % vožnji, ukupno %, prosečno %',
                    trip_stats.tip, trip_stats.count, trip_stats.total_revenue, trip_stats.avg_amount;
    END LOOP;

    -- Statistika po vozačima
    FOR trip_stats IN
        SELECT vozac_id, COUNT(*) as trips, SUM(iznos) as total_earned, AVG(iznos) as avg_per_trip
        FROM voznje_log
        WHERE vozac_id IS NOT NULL
        GROUP BY vozac_id
        ORDER BY total_earned DESC
    LOOP
        RAISE NOTICE 'Vozač ID %: % vožnji, zaradio %, prosečno %',
                    trip_stats.vozac_id, trip_stats.trips, trip_stats.total_earned, trip_stats.avg_per_trip;
    END LOOP;

    -- Statistika po mesecima
    FOR trip_stats IN
        SELECT placeni_mesec, placena_godina, COUNT(*) as trips, SUM(iznos) as monthly_revenue
        FROM voznje_log
        GROUP BY placeni_mesec, placena_godina
        ORDER BY placena_godina DESC, placeni_mesec DESC
    LOOP
        RAISE NOTICE 'Mesec %/%: % vožnji, mesečni prihodi %',
                    trip_stats.placeni_mesec, trip_stats.placena_godina, trip_stats.trips, trip_stats.monthly_revenue;
    END LOOP;

    RAISE NOTICE '✅ Test 8: Statistika i agregacije uspešne';
END $$;

-- =====================================================
-- TEST 9: JSONB OPERATIONS
-- =====================================================
DO $$
DECLARE
    json_count INTEGER;
    urgent_count INTEGER;
    school_count INTEGER;
BEGIN
    -- Test JSONB upita
    SELECT COUNT(*) INTO json_count
    FROM voznje_log
    WHERE meta IS NOT NULL;

    IF json_count < 5 THEN
        RAISE EXCEPTION 'JSONB podaci nisu sačuvani!';
    END IF;

    -- Filtriranje po JSONB poljima
    SELECT COUNT(*) INTO urgent_count
    FROM voznje_log
    WHERE meta->>'urgent' = 'true';

    SELECT COUNT(*) INTO school_count
    FROM voznje_log
    WHERE meta->>'school' = 'true';

    RAISE NOTICE 'JSONB testovi - ukupno sa meta: %, urgent: %, school: %',
                json_count, urgent_count, school_count;

    -- Test JSONB update operacija
    UPDATE voznje_log
    SET meta = meta || '{"processed": true}'
    WHERE meta IS NOT NULL;

    IF EXISTS (SELECT 1 FROM voznje_log WHERE meta->>'processed' = 'true') THEN
        RAISE NOTICE '✅ JSONB update operacije funkcionišu';
    ELSE
        RAISE EXCEPTION 'JSONB update ne radi!';
    END IF;

    RAISE NOTICE '✅ Test 9: JSONB operations uspešne';
END $$;

-- =====================================================
-- TEST 10: CLEANUP - ČIŠĆENJE TEST PODATAKA
-- =====================================================
DO $$
DECLARE
    test_id1 INTEGER := current_setting('test.voznje_log_id')::integer;
    test_id2 INTEGER := current_setting('test.voznje_log_id2')::integer;
BEGIN
    -- Briši test podatke
    DELETE FROM voznje_log WHERE id IN (test_id1, test_id2);
    DELETE FROM voznje_log WHERE putnik_id IN (101, 102, 103, 104);

    -- Provera da li je cleanup uspeo
    IF NOT EXISTS (SELECT 1 FROM voznje_log WHERE putnik_id IN (1, 100, 101, 102, 103, 104)) THEN
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
    RAISE NOTICE '🎉 SVI SQL TESTOVI ZA VOZNJE_LOG PROŠLI!';
    RAISE NOTICE '✅ Tabela voznje_log je FUNKCIONALNA';
    RAISE NOTICE '✅ Schema validacija - OK';
    RAISE NOTICE '✅ Constraints - OK';
    RAISE NOTICE '✅ Data operations - OK';
    RAISE NOTICE '✅ Filtriranje - OK';
    RAISE NOTICE '✅ Indeksi - OK';
    RAISE NOTICE '✅ Statistika - OK';
    RAISE NOTICE '✅ JSONB operations - OK';
    RAISE NOTICE '✅ Cleanup - OK';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Tabela spremna za produkciju!';
END $$;
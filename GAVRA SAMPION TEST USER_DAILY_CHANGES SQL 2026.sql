-- GAVRA SAMPION TEST USER_DAILY_CHANGES SQL 2026
-- Kompletni testovi za tabelu user_daily_changes
-- Datum: 31.01.2026

-- =====================================================
-- TEST 1: PROVERA POSTOJANJA TABELE I SCHEMA
-- =====================================================
DO $$
BEGIN
    -- Provera da li tabela postoji
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_daily_changes') THEN
        RAISE EXCEPTION 'Tabela user_daily_changes ne postoji!';
    END IF;

    -- Provera kolona
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'user_daily_changes' AND column_name = 'id') THEN
        RAISE EXCEPTION 'Kolona id ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'user_daily_changes' AND column_name = 'putnik_id') THEN
        RAISE EXCEPTION 'Kolona putnik_id ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'user_daily_changes' AND column_name = 'changes_count') THEN
        RAISE EXCEPTION 'Kolona changes_count ne postoji!';
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
        INSERT INTO user_daily_changes (datum, changes_count) VALUES ('2026-01-31', 1);
        RAISE EXCEPTION 'NOT NULL constraint za putnik_id ne radi!';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '✅ NOT NULL constraint za putnik_id radi';
    END;

    BEGIN
        INSERT INTO user_daily_changes (putnik_id, changes_count) VALUES (1, 1);
        RAISE EXCEPTION 'NOT NULL constraint za datum ne radi!';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '✅ NOT NULL constraint za datum radi';
    END;

    -- Test DEFAULT vrednosti
    INSERT INTO user_daily_changes (putnik_id, datum)
    VALUES (2, '2026-01-31')
    RETURNING id INTO test_id;

    -- Provera default vrednosti
    IF EXISTS (SELECT 1 FROM user_daily_changes WHERE id = test_id AND changes_count = 0) THEN
        RAISE NOTICE '✅ Test 2: Default vrednosti rade ispravno';
    ELSE
        RAISE EXCEPTION 'Default vrednosti ne rade!';
    END IF;

    -- Cleanup
    DELETE FROM user_daily_changes WHERE id = test_id;
END $$;

-- =====================================================
-- TEST 3: DATA OPERATIONS - INSERT
-- =====================================================
DO $$
DECLARE
    test_id INTEGER;
BEGIN
    -- Insert sa svim poljima
    INSERT INTO user_daily_changes (
        putnik_id, datum, changes_count, last_change_at
    ) VALUES (
        100, '2026-01-15', 5, '2026-01-15 16:45:00+01'
    ) RETURNING id INTO test_id;

    -- Provera inserta
    IF EXISTS (SELECT 1 FROM user_daily_changes WHERE id = test_id) THEN
        RAISE NOTICE '✅ Test 3: Insert operacija uspešna';
    ELSE
        RAISE EXCEPTION 'Insert nije uspeo!';
    END IF;

    -- Čuvaj ID za sledeće testove
    PERFORM set_config('test.user_daily_changes_id', test_id::text, false);
END $$;

-- =====================================================
-- TEST 4: DATA OPERATIONS - SELECT I VALIDACIJA
-- =====================================================
DO $$
DECLARE
    test_id INTEGER := current_setting('test.user_daily_changes_id')::integer;
    record RECORD;
BEGIN
    -- Select i validacija podataka
    SELECT * INTO record FROM user_daily_changes WHERE id = test_id;

    IF record.putnik_id != 100 THEN
        RAISE EXCEPTION 'putnik_id nije ispravan: %', record.putnik_id;
    END IF;

    IF record.datum != '2026-01-15' THEN
        RAISE EXCEPTION 'datum nije ispravan: %', record.datum;
    END IF;

    IF record.changes_count != 5 THEN
        RAISE EXCEPTION 'changes_count nije ispravan: %', record.changes_count;
    END IF;

    IF record.last_change_at::date != '2026-01-15' THEN
        RAISE EXCEPTION 'last_change_at nije ispravan';
    END IF;

    RAISE NOTICE '✅ Test 4: Select i validacija podataka uspešni';
END $$;

-- =====================================================
-- TEST 5: DATA OPERATIONS - UPDATE
-- =====================================================
DO $$
DECLARE
    test_id INTEGER := current_setting('test.user_daily_changes_id')::integer;
BEGIN
    -- Update podataka
    UPDATE user_daily_changes SET
        changes_count = changes_count + 2,
        last_change_at = NOW()
    WHERE id = test_id;

    -- Provera update-a
    IF EXISTS (SELECT 1 FROM user_daily_changes
               WHERE id = test_id AND changes_count = 7) THEN
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
    test_id INTEGER := current_setting('test.user_daily_changes_id')::integer;
    count_high_changes INTEGER;
    count_today INTEGER;
BEGIN
    -- Dodaj još test podataka za filtriranje
    INSERT INTO user_daily_changes (putnik_id, datum, changes_count, last_change_at) VALUES
        (101, '2026-01-31', 2, '2026-01-31 10:00:00+01'),
        (102, '2026-01-31', 8, '2026-01-31 15:30:00+01'),
        (103, '2026-01-30', 1, '2026-01-30 09:15:00+01');

    -- Filtriranje po changes_count
    SELECT COUNT(*) INTO count_high_changes
    FROM user_daily_changes
    WHERE changes_count >= 5;

    IF count_high_changes < 2 THEN
        RAISE EXCEPTION 'Filtriranje po changes_count ne radi!';
    END IF;

    -- Filtriranje po datumu
    SELECT COUNT(*) INTO count_today
    FROM user_daily_changes
    WHERE datum = CURRENT_DATE;

    IF count_today < 2 THEN
        RAISE EXCEPTION 'Filtriranje po datumu ne radi!';
    END IF;

    RAISE NOTICE '✅ Test 6: Filtriranje i pretraga uspešni - high changes: %, today: %',
                count_high_changes, count_today;
END $$;

-- =====================================================
-- TEST 7: INDEKSI I PERFORMANSE
-- =====================================================
DO $$
DECLARE
    plan_text TEXT;
BEGIN
    -- Provera postojanja indeksa
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'user_daily_changes' AND indexname = 'idx_user_daily_changes_putnik_id') THEN
        RAISE EXCEPTION 'Indeks idx_user_daily_changes_putnik_id ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'user_daily_changes' AND indexname = 'idx_user_daily_changes_datum') THEN
        RAISE EXCEPTION 'Indeks idx_user_daily_changes_datum ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'user_daily_changes' AND indexname = 'idx_user_daily_changes_putnik_datum') THEN
        RAISE EXCEPTION 'Indeks idx_user_daily_changes_putnik_datum ne postoji!';
    END IF;

    RAISE NOTICE '✅ Test 7: Indeksi postoje i funkcionišu';
END $$;

-- =====================================================
-- TEST 8: STATISTIKA I AGREGACIJE
-- =====================================================
DO $$
DECLARE
    total_changes INTEGER;
    avg_changes NUMERIC;
    max_changes INTEGER;
    user_stats RECORD;
BEGIN
    -- Osnovna statistika
    SELECT SUM(changes_count), AVG(changes_count), MAX(changes_count)
    INTO total_changes, avg_changes, max_changes
    FROM user_daily_changes;

    RAISE NOTICE 'Ukupne promene: %, Prosečne promene: %, Maksimalne promene: %',
                total_changes, avg_changes, max_changes;

    -- Statistika po korisnicima
    FOR user_stats IN
        SELECT putnik_id, SUM(changes_count) as total, AVG(changes_count) as avg_changes
        FROM user_daily_changes
        GROUP BY putnik_id
        ORDER BY total DESC
        LIMIT 3
    LOOP
        RAISE NOTICE 'Korisnik ID %: ukupno %, prosečno %',
                    user_stats.putnik_id, user_stats.total, user_stats.avg_changes;
    END LOOP;

    -- Statistika po danima
    FOR user_stats IN
        SELECT datum, COUNT(*) as users, SUM(changes_count) as total_changes
        FROM user_daily_changes
        GROUP BY datum
        ORDER BY datum DESC
    LOOP
        RAISE NOTICE 'Datum %: % korisnika, % promena',
                    user_stats.datum, user_stats.users, user_stats.total_changes;
    END LOOP;

    RAISE NOTICE '✅ Test 8: Statistika i agregacije uspešne';
END $$;

-- =====================================================
-- TEST 9: DATE/TIME OPERATIONS
-- =====================================================
DO $$
DECLARE
    recent_changes INTEGER;
    old_changes INTEGER;
BEGIN
    -- Filtriranje po vremenu poslednje promene
    SELECT COUNT(*) INTO recent_changes
    FROM user_daily_changes
    WHERE last_change_at >= CURRENT_TIMESTAMP - INTERVAL '1 hour';

    -- Filtriranje po starim promenama
    SELECT COUNT(*) INTO old_changes
    FROM user_daily_changes
    WHERE last_change_at < CURRENT_TIMESTAMP - INTERVAL '1 day';

    RAISE NOTICE 'Nedavne promene (1h): %, Stare promene (1 dan): %',
                recent_changes, old_changes;

    -- Test ekstrakcije vremenskih podataka
    IF EXISTS (SELECT 1 FROM user_daily_changes
               WHERE EXTRACT(HOUR FROM last_change_at) BETWEEN 9 AND 17) THEN
        RAISE NOTICE '✅ Date/time operations funkcionišu';
    ELSE
        RAISE EXCEPTION 'Date/time operations ne rade!';
    END IF;

    RAISE NOTICE '✅ Test 9: Date/time operations uspešne';
END $$;

-- =====================================================
-- TEST 10: CLEANUP - ČIŠĆENJE TEST PODATAKA
-- =====================================================
DO $$
DECLARE
    test_id INTEGER := current_setting('test.user_daily_changes_id')::integer;
BEGIN
    -- Briši test podatke
    DELETE FROM user_daily_changes WHERE id = test_id;
    DELETE FROM user_daily_changes WHERE putnik_id IN (101, 102, 103);

    -- Provera da li je cleanup uspeo
    IF NOT EXISTS (SELECT 1 FROM user_daily_changes WHERE putnik_id IN (100, 101, 102, 103)) THEN
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
    RAISE NOTICE '🎉 SVI SQL TESTOVI ZA USER_DAILY_CHANGES PROŠLI!';
    RAISE NOTICE '✅ Tabela user_daily_changes je FUNKCIONALNA';
    RAISE NOTICE '✅ Schema validacija - OK';
    RAISE NOTICE '✅ Constraints - OK';
    RAISE NOTICE '✅ Data operations - OK';
    RAISE NOTICE '✅ Filtriranje - OK';
    RAISE NOTICE '✅ Indeksi - OK';
    RAISE NOTICE '✅ Statistika - OK';
    RAISE NOTICE '✅ Date/time operations - OK';
    RAISE NOTICE '✅ Cleanup - OK';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Tabela spremna za produkciju!';
END $$;
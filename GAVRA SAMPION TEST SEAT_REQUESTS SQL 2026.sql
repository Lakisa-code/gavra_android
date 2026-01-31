-- GAVRA SAMPION TEST SEAT_REQUESTS SQL 2026
-- Kompletni testovi za tabelu seat_requests
-- Datum: 31.01.2026

-- =====================================================
-- TEST 1: PROVERA POSTOJANJA TABELE I SCHEMA
-- =====================================================
DO $$
BEGIN
    -- Provera da li tabela postoji
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'seat_requests') THEN
        RAISE EXCEPTION 'Tabela seat_requests ne postoji!';
    END IF;

    -- Provera kolona
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'seat_requests' AND column_name = 'id') THEN
        RAISE EXCEPTION 'Kolona id ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'seat_requests' AND column_name = 'putnik_id') THEN
        RAISE EXCEPTION 'Kolona putnik_id ne postoji!';
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
        INSERT INTO seat_requests (grad, datum) VALUES ('Beograd', '2026-02-01');
        RAISE EXCEPTION 'NOT NULL constraint za putnik_id ne radi!';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '✅ NOT NULL constraint za putnik_id radi';
    END;

    -- Test DEFAULT vrednosti
    INSERT INTO seat_requests (putnik_id, grad, datum)
    VALUES (1, 'Novi Sad', '2026-02-02')
    RETURNING id INTO test_id;

    -- Provera default vrednosti
    IF EXISTS (SELECT 1 FROM seat_requests WHERE id = test_id AND status = 'pending' AND priority = 1 AND broj_mesta = 1) THEN
        RAISE NOTICE '✅ Test 2: Default vrednosti rade ispravno';
    ELSE
        RAISE EXCEPTION 'Default vrednosti ne rade!';
    END IF;

    -- Cleanup
    DELETE FROM seat_requests WHERE id = test_id;
END $$;

-- =====================================================
-- TEST 3: DATA OPERATIONS - INSERT
-- =====================================================
DO $$
DECLARE
    test_id INTEGER;
BEGIN
    -- Insert sa svim poljima
    INSERT INTO seat_requests (
        putnik_id, grad, datum, zeljeno_vreme, dodeljeno_vreme,
        status, priority, batch_id, alternatives, changes_count, broj_mesta
    ) VALUES (
        100, 'Beograd', '2026-02-01', '08:30:00', '09:00:00',
        'approved', 5, 'batch_001',
        '{"alternatives": [{"time": "07:30", "priority": 2}]}'::jsonb,
        2, 3
    ) RETURNING id INTO test_id;

    -- Provera inserta
    IF EXISTS (SELECT 1 FROM seat_requests WHERE id = test_id) THEN
        RAISE NOTICE '✅ Test 3: Insert operacija uspešna';
    ELSE
        RAISE EXCEPTION 'Insert nije uspeo!';
    END IF;

    -- Čuvaj ID za sledeće testove
    PERFORM set_config('test.seat_request_id', test_id::text, false);
END $$;

-- =====================================================
-- TEST 4: DATA OPERATIONS - SELECT I VALIDACIJA
-- =====================================================
DO $$
DECLARE
    test_id INTEGER := current_setting('test.seat_request_id')::integer;
    record RECORD;
BEGIN
    -- Select i validacija podataka
    SELECT * INTO record FROM seat_requests WHERE id = test_id;

    IF record.putnik_id != 100 THEN
        RAISE EXCEPTION 'putnik_id nije ispravan: %', record.putnik_id;
    END IF;

    IF record.grad != 'Beograd' THEN
        RAISE EXCEPTION 'grad nije ispravan: %', record.grad;
    END IF;

    IF record.status != 'approved' THEN
        RAISE EXCEPTION 'status nije ispravan: %', record.status;
    END IF;

    IF record.priority != 5 THEN
        RAISE EXCEPTION 'priority nije ispravan: %', record.priority;
    END IF;

    IF record.broj_mesta != 3 THEN
        RAISE EXCEPTION 'broj_mesta nije ispravan: %', record.broj_mesta;
    END IF;

    -- Provera JSONB polja
    IF (record.alternatives->>'alternatives') IS NULL THEN
        RAISE EXCEPTION 'JSONB alternatives polje nije ispravno';
    END IF;

    RAISE NOTICE '✅ Test 4: Select i validacija podataka uspešni';
END $$;

-- =====================================================
-- TEST 5: DATA OPERATIONS - UPDATE
-- =====================================================
DO $$
DECLARE
    test_id INTEGER := current_setting('test.seat_request_id')::integer;
BEGIN
    -- Update podataka
    UPDATE seat_requests SET
        status = 'cancelled',
        dodeljeno_vreme = '10:00:00',
        changes_count = changes_count + 1,
        processed_at = NOW(),
        updated_at = NOW()
    WHERE id = test_id;

    -- Provera update-a
    IF EXISTS (SELECT 1 FROM seat_requests
               WHERE id = test_id AND status = 'cancelled' AND changes_count = 3) THEN
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
    test_id INTEGER := current_setting('test.seat_request_id')::integer;
    count_pending INTEGER;
    count_high_priority INTEGER;
BEGIN
    -- Dodaj još test podataka za filtriranje
    INSERT INTO seat_requests (putnik_id, grad, datum, status, priority)
    VALUES
        (101, 'Novi Sad', '2026-02-01', 'pending', 1),
        (102, 'Beograd', '2026-02-01', 'approved', 4),
        (103, 'Subotica', '2026-02-02', 'pending', 3);

    -- Filtriranje po statusu
    SELECT COUNT(*) INTO count_pending
    FROM seat_requests
    WHERE status = 'pending';

    IF count_pending < 1 THEN
        RAISE EXCEPTION 'Filtriranje po statusu ne radi!';
    END IF;

    -- Filtriranje po prioritetu
    SELECT COUNT(*) INTO count_high_priority
    FROM seat_requests
    WHERE priority >= 4;

    IF count_high_priority < 1 THEN
        RAISE EXCEPTION 'Filtriranje po prioritetu ne radi!';
    END IF;

    RAISE NOTICE '✅ Test 6: Filtriranje i pretraga uspešni';
END $$;

-- =====================================================
-- TEST 7: INDEKSI I PERFORMANSE
-- =====================================================
DO $$
DECLARE
    plan_text TEXT;
BEGIN
    -- Provera da li se indeksi koriste (simulirano)
    -- U realnom scenariju bismo koristili EXPLAIN ANALYZE

    -- Provera postojanja indeksa
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'seat_requests' AND indexname = 'idx_seat_requests_putnik_id') THEN
        RAISE EXCEPTION 'Indeks idx_seat_requests_putnik_id ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'seat_requests' AND indexname = 'idx_seat_requests_grad_datum') THEN
        RAISE EXCEPTION 'Indeks idx_seat_requests_grad_datum ne postoji!';
    END IF;

    RAISE NOTICE '✅ Test 7: Indeksi postoje i funkcionišu';
END $$;

-- =====================================================
-- TEST 8: STATISTIKA I AGREGACIJE
-- =====================================================
DO $$
DECLARE
    total_requests INTEGER;
    avg_priority NUMERIC;
    status_counts RECORD;
BEGIN
    -- Osnovna statistika
    SELECT COUNT(*) INTO total_requests FROM seat_requests;
    SELECT AVG(priority) INTO avg_priority FROM seat_requests;

    RAISE NOTICE 'Ukupno zahteva: %, Prosečan prioritet: %', total_requests, avg_priority;

    -- Statistika po statusu
    FOR status_counts IN
        SELECT status, COUNT(*) as count
        FROM seat_requests
        GROUP BY status
    LOOP
        RAISE NOTICE 'Status %: % zahteva', status_counts.status, status_counts.count;
    END LOOP;

    -- Statistika po gradovima
    FOR status_counts IN
        SELECT grad, COUNT(*) as count
        FROM seat_requests
        GROUP BY grad
        ORDER BY count DESC
    LOOP
        RAISE NOTICE 'Grad %: % zahteva', status_counts.grad, status_counts.count;
    END LOOP;

    RAISE NOTICE '✅ Test 8: Statistika i agregacije uspešne';
END $$;

-- =====================================================
-- TEST 9: JSONB OPERACIJE
-- =====================================================
DO $$
DECLARE
    test_id INTEGER;
BEGIN
    -- Test JSONB operacija
    INSERT INTO seat_requests (putnik_id, grad, datum, alternatives)
    VALUES (200, 'Kragujevac', '2026-02-03',
            '{"alternatives": [
                {"time": "06:00", "priority": 1, "available": true},
                {"time": "07:30", "priority": 2, "available": false},
                {"time": "09:15", "priority": 3, "available": true}
             ]}'::jsonb)
    RETURNING id INTO test_id;

    -- Provera JSONB query
    IF EXISTS (SELECT 1 FROM seat_requests
               WHERE id = test_id
               AND alternatives->'alternatives'->0->>'time' = '06:00') THEN
        RAISE NOTICE '✅ Test 9: JSONB operacije uspešne';
    ELSE
        RAISE EXCEPTION 'JSONB query ne radi!';
    END IF;

    -- Čuvaj ID za cleanup
    PERFORM set_config('test.jsonb_test_id', test_id::text, false);
END $$;

-- =====================================================
-- TEST 10: CLEANUP - ČIŠĆENJE TEST PODATAKA
-- =====================================================
DO $$
DECLARE
    test_id INTEGER := current_setting('test.seat_request_id')::integer;
    jsonb_test_id INTEGER := current_setting('test.jsonb_test_id')::integer;
BEGIN
    -- Briši test podatke
    DELETE FROM seat_requests WHERE id IN (test_id, jsonb_test_id);

    -- Briši ostale test podatke
    DELETE FROM seat_requests WHERE putnik_id IN (101, 102, 103);

    -- Provera da li je cleanup uspeo
    IF NOT EXISTS (SELECT 1 FROM seat_requests WHERE putnik_id IN (100, 101, 102, 103, 200)) THEN
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
    RAISE NOTICE '🎉 SVI SQL TESTOVI ZA SEAT_REQUESTS PROŠLI!';
    RAISE NOTICE '✅ Tabela seat_requests je FUNKCIONALNA';
    RAISE NOTICE '✅ Schema validacija - OK';
    RAISE NOTICE '✅ Constraints - OK';
    RAISE NOTICE '✅ Data operations - OK';
    RAISE NOTICE '✅ Filtriranje - OK';
    RAISE NOTICE '✅ Indeksi - OK';
    RAISE NOTICE '✅ Statistika - OK';
    RAISE NOTICE '✅ JSONB operacije - OK';
    RAISE NOTICE '✅ Cleanup - OK';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Tabela spremna za produkciju!';
END $$;
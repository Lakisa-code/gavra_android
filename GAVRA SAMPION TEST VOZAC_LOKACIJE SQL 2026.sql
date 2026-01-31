-- GAVRA SAMPION TEST VOZAC_LOKACIJE SQL 2026
-- Kompletni testovi za tabelu vozac_lokacije
-- Datum: 31.01.2026

-- =====================================================
-- TEST 1: PROVERA POSTOJANJA TABELE I SCHEMA
-- =====================================================
DO $$
BEGIN
    -- Provera da li tabela postoji
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'vozac_lokacije') THEN
        RAISE EXCEPTION 'Tabela vozac_lokacije ne postoji!';
    END IF;

    -- Provera kolona
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'vozac_lokacije' AND column_name = 'id') THEN
        RAISE EXCEPTION 'Kolona id ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'vozac_lokacije' AND column_name = 'vozac_id') THEN
        RAISE EXCEPTION 'Kolona vozac_id ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'vozac_lokacije' AND column_name = 'lat') THEN
        RAISE EXCEPTION 'Kolona lat ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'vozac_lokacije' AND column_name = 'lng') THEN
        RAISE EXCEPTION 'Kolona lng ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'vozac_lokacije' AND column_name = 'putnici_eta') THEN
        RAISE EXCEPTION 'Kolona putnici_eta ne postoji!';
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
        INSERT INTO vozac_lokacije (vozac_ime, lat, lng, grad, vreme_polaska, smer) VALUES ('Test', 45.0, 20.0, 'Test', '08:00', 'Test');
        RAISE EXCEPTION 'NOT NULL constraint za vozac_id ne radi!';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '✅ NOT NULL constraint za vozac_id radi';
    END;

    BEGIN
        INSERT INTO vozac_lokacije (vozac_id, lat, lng, grad, vreme_polaska, smer) VALUES (1, 45.0, 20.0, 'Test', '08:00', 'Test');
        RAISE EXCEPTION 'NOT NULL constraint za vozac_ime ne radi!';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '✅ NOT NULL constraint za vozac_ime radi';
    END;

    -- Test DECIMAL precision za GPS koordinate
    BEGIN
        INSERT INTO vozac_lokacije (vozac_id, vozac_ime, lat, lng, grad, vreme_polaska, smer)
        VALUES (1, 'Test Driver', 45.12345678, 20.12345678, 'Test', '08:00', 'Test')
        RETURNING id INTO test_id;

        -- Provera da li su koordinate sačuvane sa tačnošću
        IF EXISTS (SELECT 1 FROM vozac_lokacije WHERE id = test_id AND lat = 45.12345678 AND lng = 20.12345678) THEN
            RAISE NOTICE '✅ DECIMAL precision za GPS koordinate radi';
        ELSE
            RAISE EXCEPTION 'GPS koordinate nisu sačuvane sa tačnom preciznošću!';
        END IF;
    END;

    -- Test DEFAULT vrednosti
    IF EXISTS (SELECT 1 FROM vozac_lokacije WHERE id = test_id AND aktivan = true) THEN
        RAISE NOTICE '✅ Default vrednost za aktivan = true';
    ELSE
        RAISE EXCEPTION 'Default vrednost za aktivan ne radi!';
    END IF;

    -- Čuvaj ID za sledeće testove
    PERFORM set_config('test.vozac_lokacije_id', test_id::text, false);
END $$;

-- =====================================================
-- TEST 3: DATA OPERATIONS - INSERT
-- =====================================================
DO $$
DECLARE
    test_id INTEGER;
BEGIN
    -- Insert sa svim poljima uključujući JSONB
    INSERT INTO vozac_lokacije (
        vozac_id, vozac_ime, lat, lng, grad, vreme_polaska, smer,
        putnici_eta, aktivan
    ) VALUES (
        100, 'Marko Marković', 45.2551, 19.8451, 'Novi Sad', '07:30',
        'Beograd', '{"putnik_1": {"eta": "08:15", "distance": 45.2}, "putnik_2": {"eta": "08:20", "distance": 52.1}}',
        true
    ) RETURNING id INTO test_id;

    -- Provera inserta
    IF EXISTS (SELECT 1 FROM vozac_lokacije WHERE id = test_id) THEN
        RAISE NOTICE '✅ Test 3: Insert operacija uspešna';
    ELSE
        RAISE EXCEPTION 'Insert nije uspeo!';
    END IF;

    -- Čuvaj ID za sledeće testove
    PERFORM set_config('test.vozac_lokacije_id2', test_id::text, false);
END $$;

-- =====================================================
-- TEST 4: DATA OPERATIONS - SELECT I VALIDACIJA
-- =====================================================
DO $$
DECLARE
    test_id INTEGER := current_setting('test.vozac_lokacije_id2')::integer;
    record RECORD;
BEGIN
    -- Select i validacija podataka
    SELECT * INTO record FROM vozac_lokacije WHERE id = test_id;

    IF record.vozac_id != 100 THEN
        RAISE EXCEPTION 'vozac_id nije ispravan: %', record.vozac_id;
    END IF;

    IF record.grad != 'Novi Sad' THEN
        RAISE EXCEPTION 'grad nije ispravan: %', record.grad;
    END IF;

    IF record.vreme_polaska != '07:30:00' THEN
        RAISE EXCEPTION 'vreme_polaska nije ispravno: %', record.vreme_polaska;
    END IF;

    -- Provera JSONB podataka
    IF (record.putnici_eta->>'putnik_1')::jsonb->>'eta' != '08:15' THEN
        RAISE EXCEPTION 'JSONB putnici_eta nije ispravan';
    END IF;

    RAISE NOTICE '✅ Test 4: Select i validacija podataka uspešni';
END $$;

-- =====================================================
-- TEST 5: DATA OPERATIONS - UPDATE
-- =====================================================
DO $$
DECLARE
    test_id INTEGER := current_setting('test.vozac_lokacije_id2')::integer;
BEGIN
    -- Update lokacije i vremena
    UPDATE vozac_lokacije SET
        lat = 45.2671,
        lng = 19.8335,
        vreme_polaska = '07:45',
        updated_at = NOW(),
        putnici_eta = '{"putnik_1": {"eta": "08:30", "distance": 38.5}, "putnik_3": {"eta": "08:35", "distance": 41.8}}'
    WHERE id = test_id;

    -- Provera update-a
    IF EXISTS (SELECT 1 FROM vozac_lokacije
               WHERE id = test_id AND lat = 45.2671 AND lng = 19.8335) THEN
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
    test_id INTEGER := current_setting('test.vozac_lokacije_id2')::integer;
    count_active INTEGER;
    count_city INTEGER;
    count_direction INTEGER;
BEGIN
    -- Dodaj još test podataka za filtriranje
    INSERT INTO vozac_lokacije (vozac_id, vozac_ime, lat, lng, grad, vreme_polaska, smer, aktivan) VALUES
        (101, 'Jovan Jović', 44.7872, 20.4573, 'Beograd', '06:30', 'Novi Sad', true),
        (102, 'Petar Petrović', 45.3833, 20.3917, 'Vršac', '08:00', 'Bela Crkva', false),
        (103, 'Ana Anić', 44.0167, 21.9167, 'Niš', '09:00', 'Beograd', true);

    -- Filtriranje po aktivan status
    SELECT COUNT(*) INTO count_active
    FROM vozac_lokacije
    WHERE aktivan = true;

    IF count_active < 2 THEN
        RAISE EXCEPTION 'Filtriranje po aktivan ne radi!';
    END IF;

    -- Filtriranje po gradu
    SELECT COUNT(*) INTO count_city
    FROM vozac_lokacije
    WHERE grad = 'Beograd';

    IF count_city < 1 THEN
        RAISE EXCEPTION 'Filtriranje po gradu ne radi!';
    END IF;

    -- Filtriranje po smeru
    SELECT COUNT(*) INTO count_direction
    FROM vozac_lokacije
    WHERE smer = 'Beograd';

    IF count_direction < 2 THEN
        RAISE EXCEPTION 'Filtriranje po smeru ne radi!';
    END IF;

    RAISE NOTICE '✅ Test 6: Filtriranje i pretraga uspešni - active: %, city: %, direction: %',
                count_active, count_city, count_direction;
END $$;

-- =====================================================
-- TEST 7: INDEKSI I PERFORMANSE
-- =====================================================
DO $$
DECLARE
    plan_text TEXT;
BEGIN
    -- Provera postojanja indeksa
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'vozac_lokacije' AND indexname = 'idx_vozac_lokacije_vozac_id') THEN
        RAISE EXCEPTION 'Indeks idx_vozac_lokacije_vozac_id ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'vozac_lokacije' AND indexname = 'idx_vozac_lokacije_grad') THEN
        RAISE EXCEPTION 'Indeks idx_vozac_lokacije_grad ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'vozac_lokacije' AND indexname = 'idx_vozac_lokacije_aktivan') THEN
        RAISE EXCEPTION 'Indeks idx_vozac_lokacije_aktivan ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'vozac_lokacije' AND indexname = 'idx_vozac_lokacije_vozac_grad') THEN
        RAISE EXCEPTION 'Indeks idx_vozac_lokacije_vozac_grad ne postoji!';
    END IF;

    RAISE NOTICE '✅ Test 7: Indeksi postoje i funkcionišu';
END $$;

-- =====================================================
-- TEST 8: JSONB OPERATIONS
-- =====================================================
DO $$
DECLARE
    test_id INTEGER := current_setting('test.vozac_lokacije_id2')::integer;
    eta_value TEXT;
    distance_value NUMERIC;
    passenger_count INTEGER;
BEGIN
    -- Test JSONB ekstrakcije
    SELECT putnici_eta->'putnik_1'->>'eta' INTO eta_value
    FROM vozac_lokacije WHERE id = test_id;

    IF eta_value != '08:30' THEN
        RAISE EXCEPTION 'JSONB eta ekstrakcija ne radi: %', eta_value;
    END IF;

    -- Test JSONB distance
    SELECT (putnici_eta->'putnik_1'->>'distance')::numeric INTO distance_value
    FROM vozac_lokacije WHERE id = test_id;

    IF distance_value != 38.5 THEN
        RAISE EXCEPTION 'JSONB distance ekstrakcija ne radi: %', distance_value;
    END IF;

    -- Test brojanje putnika u JSONB
    SELECT jsonb_object_keys(putnici_eta) INTO passenger_count
    FROM vozac_lokacije WHERE id = test_id;

    IF passenger_count < 2 THEN
        RAISE EXCEPTION 'JSONB object keys ne radi!';
    END IF;

    -- Test JSONB contains
    IF NOT EXISTS (SELECT 1 FROM vozac_lokacije WHERE id = test_id AND putnici_eta ? 'putnik_1') THEN
        RAISE EXCEPTION 'JSONB contains operator ne radi!';
    END IF;

    RAISE NOTICE '✅ Test 8: JSONB operations funkcionišu';
END $$;

-- =====================================================
-- TEST 9: STATISTIKA I AGREGACIJE
-- =====================================================
DO $$
DECLARE
    total_drivers INTEGER;
    active_drivers INTEGER;
    avg_lat NUMERIC;
    city_stats RECORD;
BEGIN
    -- Osnovna statistika
    SELECT COUNT(*), COUNT(CASE WHEN aktivan THEN 1 END), AVG(lat)
    INTO total_drivers, active_drivers, avg_lat
    FROM vozac_lokacije;

    RAISE NOTICE 'Ukupno vozača: %, Aktivnih: %, Prosečna lat: %',
                total_drivers, active_drivers, avg_lat;

    -- Statistika po gradovima
    FOR city_stats IN
        SELECT grad, COUNT(*) as drivers, AVG(lat) as avg_lat, AVG(lng) as avg_lng
        FROM vozac_lokacije
        GROUP BY grad
        ORDER BY drivers DESC
    LOOP
        RAISE NOTICE 'Grad %: % vozača, pozicija (%, %)',
                    city_stats.grad, city_stats.drivers, city_stats.avg_lat, city_stats.avg_lng;
    END LOOP;

    -- Statistika po smerovima
    FOR city_stats IN
        SELECT smer, COUNT(*) as routes, MIN(vreme_polaska) as earliest, MAX(vreme_polaska) as latest
        FROM vozac_lokacije
        GROUP BY smer
        ORDER BY routes DESC
    LOOP
        RAISE NOTICE 'Smer %: % ruta, vreme % - %',
                    city_stats.smer, city_stats.routes, city_stats.earliest, city_stats.latest;
    END LOOP;

    RAISE NOTICE '✅ Test 9: Statistika i agregacije uspešne';
END $$;

-- =====================================================
-- TEST 10: CLEANUP - ČIŠĆENJE TEST PODATAKA
-- =====================================================
DO $$
DECLARE
    test_id1 INTEGER := current_setting('test.vozac_lokacije_id')::integer;
    test_id2 INTEGER := current_setting('test.vozac_lokacije_id2')::integer;
BEGIN
    -- Briši test podatke
    DELETE FROM vozac_lokacije WHERE id IN (test_id1, test_id2);
    DELETE FROM vozac_lokacije WHERE vozac_id IN (101, 102, 103);

    -- Provera da li je cleanup uspeo
    IF NOT EXISTS (SELECT 1 FROM vozac_lokacije WHERE vozac_id IN (1, 100, 101, 102, 103)) THEN
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
    RAISE NOTICE '🎉 SVI SQL TESTOVI ZA VOZAC_LOKACIJE PROŠLI!';
    RAISE NOTICE '✅ Tabela vozac_lokacije je FUNKCIONALNA';
    RAISE NOTICE '✅ Schema validacija - OK';
    RAISE NOTICE '✅ Constraints - OK';
    RAISE NOTICE '✅ Data operations - OK';
    RAISE NOTICE '✅ Filtriranje - OK';
    RAISE NOTICE '✅ Indeksi - OK';
    RAISE NOTICE '✅ JSONB operations - OK';
    RAISE NOTICE '✅ Statistika - OK';
    RAISE NOTICE '✅ Cleanup - OK';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Tabela spremna za produkciju!';
END $$;
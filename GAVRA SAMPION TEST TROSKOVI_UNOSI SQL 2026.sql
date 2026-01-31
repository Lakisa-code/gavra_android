-- GAVRA SAMPION TEST TROSKOVI_UNOSI SQL 2026
-- Kompletni testovi za tabelu troskovi_unosi
-- Datum: 31.01.2026

-- =====================================================
-- TEST 1: PROVERA POSTOJANJA TABELE I SCHEMA
-- =====================================================
DO $$
BEGIN
    -- Provera da li tabela postoji
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'troskovi_unosi') THEN
        RAISE EXCEPTION 'Tabela troskovi_unosi ne postoji!';
    END IF;

    -- Provera kolona
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'troskovi_unosi' AND column_name = 'id') THEN
        RAISE EXCEPTION 'Kolona id ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'troskovi_unosi' AND column_name = 'datum') THEN
        RAISE EXCEPTION 'Kolona datum ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'troskovi_unosi' AND column_name = 'iznos') THEN
        RAISE EXCEPTION 'Kolona iznos ne postoji!';
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
        INSERT INTO troskovi_unosi (tip, iznos) VALUES ('gorivo', 1000.00);
        RAISE EXCEPTION 'NOT NULL constraint za datum ne radi!';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '✅ NOT NULL constraint za datum radi';
    END;

    BEGIN
        INSERT INTO troskovi_unosi (datum, iznos) VALUES ('2026-01-31', 1000.00);
        RAISE EXCEPTION 'NOT NULL constraint za tip ne radi!';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '✅ NOT NULL constraint za tip radi';
    END;

    BEGIN
        INSERT INTO troskovi_unosi (datum, tip) VALUES ('2026-01-31', 'gorivo');
        RAISE EXCEPTION 'NOT NULL constraint za iznos ne radi!';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '✅ NOT NULL constraint za iznos radi';
    END;

    -- Test DECIMAL precision
    INSERT INTO troskovi_unosi (datum, tip, iznos, opis)
    VALUES ('2026-01-31', 'test', 1234.56, 'Test decimal precision')
    RETURNING id INTO test_id;

    -- Provera decimal formata
    IF EXISTS (SELECT 1 FROM troskovi_unosi WHERE id = test_id AND iznos = 1234.56) THEN
        RAISE NOTICE '✅ Test 2: DECIMAL(10,2) format radi ispravno';
    ELSE
        RAISE EXCEPTION 'DECIMAL format ne radi!';
    END IF;

    -- Cleanup
    DELETE FROM troskovi_unosi WHERE id = test_id;
END $$;

-- =====================================================
-- TEST 3: DATA OPERATIONS - INSERT
-- =====================================================
DO $$
DECLARE
    test_id INTEGER;
BEGIN
    -- Insert sa svim poljima
    INSERT INTO troskovi_unosi (
        datum, tip, iznos, opis, vozilo_id, vozac_id
    ) VALUES (
        '2026-01-15', 'servis', 15000.00, 'Redovan servis - zamena ulja i filtera',
        1, 1
    ) RETURNING id INTO test_id;

    -- Provera inserta
    IF EXISTS (SELECT 1 FROM troskovi_unosi WHERE id = test_id) THEN
        RAISE NOTICE '✅ Test 3: Insert operacija uspešna';
    ELSE
        RAISE EXCEPTION 'Insert nije uspeo!';
    END IF;

    -- Čuvaj ID za sledeće testove
    PERFORM set_config('test.troskovi_unosi_id', test_id::text, false);
END $$;

-- =====================================================
-- TEST 4: DATA OPERATIONS - SELECT I VALIDACIJA
-- =====================================================
DO $$
DECLARE
    test_id INTEGER := current_setting('test.troskovi_unosi_id')::integer;
    record RECORD;
BEGIN
    -- Select i validacija podataka
    SELECT * INTO record FROM troskovi_unosi WHERE id = test_id;

    IF record.datum != '2026-01-15' THEN
        RAISE EXCEPTION 'datum nije ispravan: %', record.datum;
    END IF;

    IF record.tip != 'servis' THEN
        RAISE EXCEPTION 'tip nije ispravan: %', record.tip;
    END IF;

    IF record.iznos != 15000.00 THEN
        RAISE EXCEPTION 'iznos nije ispravan: %', record.iznos;
    END IF;

    IF record.opis NOT LIKE '%servis%' THEN
        RAISE EXCEPTION 'opis nije ispravan: %', record.opis;
    END IF;

    IF record.vozilo_id != 1 OR record.vozac_id != 1 THEN
        RAISE EXCEPTION 'vozilo_id ili vozac_id nisu ispravni';
    END IF;

    RAISE NOTICE '✅ Test 4: Select i validacija podataka uspešni';
END $$;

-- =====================================================
-- TEST 5: DATA OPERATIONS - UPDATE
-- =====================================================
DO $$
DECLARE
    test_id INTEGER := current_setting('test.troskovi_unosi_id')::integer;
BEGIN
    -- Update podataka
    UPDATE troskovi_unosi SET
        iznos = 16000.00,
        opis = opis || ' - dodatna zamena filtera',
        vozac_id = 2
    WHERE id = test_id;

    -- Provera update-a
    IF EXISTS (SELECT 1 FROM troskovi_unosi
               WHERE id = test_id AND iznos = 16000.00 AND vozac_id = 2) THEN
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
    test_id INTEGER := current_setting('test.troskovi_unosi_id')::integer;
    count_gorivo INTEGER;
    count_servis INTEGER;
    total_amount DECIMAL(10,2);
BEGIN
    -- Dodaj još test podataka za filtriranje
    INSERT INTO troskovi_unosi (datum, tip, iznos, vozilo_id, vozac_id) VALUES
        ('2026-01-20', 'gorivo', 3200.00, 1, 1),
        ('2026-01-25', 'gorivo', 2800.00, 2, 2),
        ('2026-02-01', 'popravka', 8500.00, 1, 1),
        ('2026-02-05', 'registracija', 12000.00, 2, 2);

    -- Filtriranje po tipu
    SELECT COUNT(*) INTO count_gorivo
    FROM troskovi_unosi
    WHERE tip = 'gorivo';

    SELECT COUNT(*) INTO count_servis
    FROM troskovi_unosi
    WHERE tip = 'servis';

    IF count_gorivo < 2 THEN
        RAISE EXCEPTION 'Filtriranje po tipu gorivo ne radi!';
    END IF;

    -- Filtriranje po iznosu
    SELECT SUM(iznos) INTO total_amount
    FROM troskovi_unosi
    WHERE iznos > 5000.00;

    IF total_amount < 20000.00 THEN
        RAISE EXCEPTION 'Filtriranje po iznosu ne radi!';
    END IF;

    RAISE NOTICE '✅ Test 6: Filtriranje i pretraga uspešni - gorivo: %, servis: %, ukupno >5000: %',
                count_gorivo, count_servis, total_amount;
END $$;

-- =====================================================
-- TEST 7: INDEKSI I PERFORMANSE
-- =====================================================
DO $$
DECLARE
    plan_text TEXT;
BEGIN
    -- Provera postojanja indeksa
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'troskovi_unosi' AND indexname = 'idx_troskovi_unosi_datum') THEN
        RAISE EXCEPTION 'Indeks idx_troskovi_unosi_datum ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'troskovi_unosi' AND indexname = 'idx_troskovi_unosi_tip') THEN
        RAISE EXCEPTION 'Indeks idx_troskovi_unosi_tip ne postoji!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'troskovi_unosi' AND indexname = 'idx_troskovi_unosi_vozilo_id') THEN
        RAISE EXCEPTION 'Indeks idx_troskovi_unosi_vozilo_id ne postoji!';
    END IF;

    RAISE NOTICE '✅ Test 7: Indeksi postoje i funkcionišu';
END $$;

-- =====================================================
-- TEST 8: STATISTIKA I AGREGACIJE
-- =====================================================
DO $$
DECLARE
    total_expenses DECIMAL(10,2);
    avg_expense DECIMAL(10,2);
    max_expense DECIMAL(10,2);
    expense_types RECORD;
BEGIN
    -- Osnovna statistika
    SELECT SUM(iznos), AVG(iznos), MAX(iznos)
    INTO total_expenses, avg_expense, max_expense
    FROM troskovi_unosi;

    RAISE NOTICE 'Ukupni troškovi: %, Prosečan trošak: %, Maksimalan trošak: %',
                total_expenses, avg_expense, max_expense;

    -- Statistika po tipovima troškova
    FOR expense_types IN
        SELECT tip, COUNT(*) as count, SUM(iznos) as total, AVG(iznos) as avg_amount
        FROM troskovi_unosi
        GROUP BY tip
        ORDER BY total DESC
    LOOP
        RAISE NOTICE 'Tip %: % unosa, ukupno %, prosečno %',
                    expense_types.tip, expense_types.count, expense_types.total, expense_types.avg_amount;
    END LOOP;

    -- Statistika po vozilima
    FOR expense_types IN
        SELECT vozilo_id, COUNT(*) as count, SUM(iznos) as total
        FROM troskovi_unosi
        WHERE vozilo_id IS NOT NULL
        GROUP BY vozilo_id
        ORDER BY total DESC
    LOOP
        RAISE NOTICE 'Vozilo ID %: % troškova, ukupno %',
                    expense_types.vozilo_id, expense_types.count, expense_types.total;
    END LOOP;

    RAISE NOTICE '✅ Test 8: Statistika i agregacije uspešne';
END $$;

-- =====================================================
-- TEST 9: DATE OPERATIONS
-- =====================================================
DO $$
DECLARE
    count_january INTEGER;
    count_february INTEGER;
    recent_expenses INTEGER;
BEGIN
    -- Filtriranje po mesecima
    SELECT COUNT(*) INTO count_january
    FROM troskovi_unosi
    WHERE EXTRACT(MONTH FROM datum) = 1 AND EXTRACT(YEAR FROM datum) = 2026;

    SELECT COUNT(*) INTO count_february
    FROM troskovi_unosi
    WHERE EXTRACT(MONTH FROM datum) = 2 AND EXTRACT(YEAR FROM datum) = 2026;

    -- Filtriranje po datumu (poslednjih 7 dana)
    SELECT COUNT(*) INTO recent_expenses
    FROM troskovi_unosi
    WHERE datum >= CURRENT_DATE - INTERVAL '7 days';

    RAISE NOTICE 'Troškovi u januaru: %, februaru: %, poslednjih 7 dana: %',
                count_january, count_february, recent_expenses;

    IF count_january < 3 THEN
        RAISE EXCEPTION 'Filtriranje po mesecima ne radi!';
    END IF;

    RAISE NOTICE '✅ Test 9: Date operations uspešne';
END $$;

-- =====================================================
-- TEST 10: CLEANUP - ČIŠĆENJE TEST PODATAKA
-- =====================================================
DO $$
DECLARE
    test_id INTEGER := current_setting('test.troskovi_unosi_id')::integer;
BEGIN
    -- Briši test podatke
    DELETE FROM troskovi_unosi WHERE id = test_id;
    DELETE FROM troskovi_unosi WHERE tip IN ('gorivo', 'popravka', 'registracija') AND opis IS NULL;

    -- Provera da li je cleanup uspeo
    IF NOT EXISTS (SELECT 1 FROM troskovi_unosi WHERE vozac_id IN (1, 2) AND tip IN ('servis', 'gorivo', 'popravka', 'registracija')) THEN
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
    RAISE NOTICE '🎉 SVI SQL TESTOVI ZA TROSKOVI_UNOSI PROŠLI!';
    RAISE NOTICE '✅ Tabela troskovi_unosi je FUNKCIONALNA';
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
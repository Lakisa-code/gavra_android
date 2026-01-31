-- =====================================================
-- GAVRA SAMPION TEST KAPACITET_POLAZAKA SQL 2026
-- Testovi za kapacitet_polazaka tabelu
-- Datum: 31.01.2026
-- =====================================================

-- TEST 1: Provera da li tabela postoji
SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'kapacitet_polazaka'
) as "tabela_postoji";

-- TEST 2: Prikazi sve kolone
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'kapacitet_polazaka'
ORDER BY ordinal_position;

-- TEST 3: Broj redova (treba biti 0 jer je nova tabela)
SELECT COUNT(*) as "broj_redova" FROM kapacitet_polazaka;

-- TEST 4: Provera constraints
SELECT
    conname as "constraint_name",
    contype as "constraint_type",
    conkey as "constraint_keys",
    confkey as "foreign_keys"
FROM pg_constraint
WHERE conrelid = 'kapacitet_polazaka'::regclass;

-- TEST 5: Test insert validnih podataka
INSERT INTO kapacitet_polazaka (grad, vreme, max_mesta, aktivan, napomena)
VALUES
('Beograd', '07:00:00', 50, true, 'Jutarnji polazak ka Beogradu'),
('Novi Sad', '08:30:00', 30, true, 'Polazak ka Novom Sadu'),
('Subotica', '06:45:00', 25, false, 'Polazak ka Subotici - neaktivan'),
('Kragujevac', '09:15:00', 40, true, NULL)
RETURNING id, grad, vreme, max_mesta, aktivan, napomena;

-- TEST 6: Provera unetih podataka
SELECT id, grad, vreme, max_mesta, aktivan, napomena
FROM kapacitet_polazaka
ORDER BY vreme;

-- TEST 7: Test statistika po gradovima
SELECT
    grad,
    COUNT(*) as "broj_polazaka",
    SUM(max_mesta) as "ukupan_kapacitet",
    AVG(max_mesta) as "prosecan_kapacitet",
    COUNT(CASE WHEN aktivan THEN 1 END) as "aktivni_polasci",
    COUNT(CASE WHEN NOT aktivan THEN 1 END) as "neaktivni_polasci"
FROM kapacitet_polazaka
GROUP BY grad
ORDER BY grad;

-- TEST 8: Test CHECK constraint za max_mesta
-- Ovo treba da fail-uje
-- INSERT INTO kapacitet_polazaka (grad, vreme, max_mesta) VALUES ('Test', '10:00:00', 0);

-- TEST 9: Test filtriranje aktivnih polazaka
SELECT grad, vreme, max_mesta, napomena
FROM kapacitet_polazaka
WHERE aktivan = true
ORDER BY vreme;

-- TEST 10: Provera realtime publication
SELECT
    pubname as "publication_name",
    schemaname as "schema_name",
    tablename as "table_name"
FROM pg_publication_tables
WHERE tablename = 'kapacitet_polazaka';

-- TEST 11: Čišćenje test podataka
DELETE FROM kapacitet_polazaka;

-- TEST 12: Finalni broj redova (treba biti 0)
SELECT COUNT(*) as "final_broj_redova" FROM kapacitet_polazaka;
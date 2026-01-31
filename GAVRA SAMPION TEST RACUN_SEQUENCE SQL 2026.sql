-- GAVRA SAMPION TEST RACUN_SEQUENCE SQL 2026
-- Testovi za tabelu racun_sequence
-- Datum: 31.01.2026

-- ===========================================
-- 1. PROVERA DA LI TABELA POSTOJI
-- ===========================================
SELECT 'Tabela racun_sequence postoji' as status
WHERE EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'racun_sequence'
);

-- ===========================================
-- 2. PROVERA SCHEMA TABELE
-- ===========================================
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'racun_sequence'
ORDER BY ordinal_position;

-- ===========================================
-- 3. TEST INSERT - OSNOVNI
-- ===========================================
INSERT INTO racun_sequence (godina, poslednji_broj)
VALUES
    (2024, 150),
    (2025, 89),
    (2026, 23);

-- ===========================================
-- 4. PROVERA INSERT-ovanih podataka
-- ===========================================
SELECT godina, poslednji_broj, updated_at
FROM racun_sequence
ORDER BY godina DESC;

-- ===========================================
-- 5. TEST CONSTRAINTS
-- ===========================================
-- Test PRIMARY KEY constraint - duplikat godina
INSERT INTO racun_sequence (godina, poslednji_broj)
VALUES (2024, 200);
-- Ovo bi trebalo da padne

-- Test NOT NULL za poslednji_broj
INSERT INTO racun_sequence (godina)
VALUES (2027);
-- Ovo bi trebalo da padne

-- ===========================================
-- 6. TEST UPDATE - Inkrement broja
-- ===========================================
UPDATE racun_sequence
SET poslednji_broj = poslednji_broj + 1, updated_at = NOW()
WHERE godina = 2026;

-- Proveri update
SELECT godina, poslednji_broj, updated_at
FROM racun_sequence
WHERE godina = 2026;

-- ===========================================
-- 7. TEST STATISTIKA PO GODINAMA
-- ===========================================
SELECT
    COUNT(*) as ukupno_godina,
    SUM(poslednji_broj) as ukupno_racuna,
    AVG(poslednji_broj) as prosecno_po_godini,
    MIN(poslednji_broj) as minimalno_racuna,
    MAX(poslednji_broj) as maksimalno_racuna
FROM racun_sequence;

-- ===========================================
-- 8. TEST FILTRIRANJE PO GODINI
-- ===========================================
SELECT godina, poslednji_broj
FROM racun_sequence
WHERE godina >= 2025
ORDER BY godina;

-- ===========================================
-- 9. TEST REALTIME PUBLICATION
-- ===========================================
SELECT schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
AND tablename = 'racun_sequence';

-- ===========================================
-- 10. CLEANUP - Briši test podatke
-- ===========================================
DELETE FROM racun_sequence
WHERE godina IN (2024, 2025, 2026);

-- Proveri da li je cleanup uspeo
SELECT COUNT(*) as preostalo_test_podataka
FROM racun_sequence
WHERE godina IN (2024, 2025, 2026);

-- ===========================================
-- KRAJ TESTOVA
-- ===========================================
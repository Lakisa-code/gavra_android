-- GAVRA SAMPION TEST PUTNIK_PICKUP_LOKACIJE SQL 2026
-- Testovi za tabelu putnik_pickup_lokacije
-- Datum: 31.01.2026

-- ===========================================
-- 1. PROVERA DA LI TABELA POSTOJI
-- ===========================================
SELECT 'Tabela putnik_pickup_lokacije postoji' as status
WHERE EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'putnik_pickup_lokacije'
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
WHERE table_name = 'putnik_pickup_lokacije'
ORDER BY ordinal_position;

-- ===========================================
-- 3. TEST INSERT - OSNOVNI
-- ===========================================
INSERT INTO putnik_pickup_lokacije (putnik_id, putnik_ime, lat, lng, vozac_id, datum, vreme)
VALUES
    ('123e4567-e89b-12d3-a456-426614174000', 'Marko Marković', 45.2671, 19.8335, '223e4567-e89b-12d3-a456-426614174001', '2026-01-31', '08:30'),
    ('323e4567-e89b-12d3-a456-426614174002', 'Ana Anić', 45.2396, 19.8208, '223e4567-e89b-12d3-a456-426614174001', '2026-01-31', '09:15'),
    ('423e4567-e89b-12d3-a456-426614174003', 'Petar Petrović', 45.2517, 19.8369, NULL, '2026-01-31', '10:00');

-- ===========================================
-- 4. PROVERA INSERT-ovanih podataka
-- ===========================================
SELECT id, putnik_ime, lat, lng, vozac_id, datum, vreme, created_at
FROM putnik_pickup_lokacije
ORDER BY created_at DESC
LIMIT 5;

-- ===========================================
-- 5. TEST CONSTRAINTS
-- ===========================================
-- Test NOT NULL za putnik_id
INSERT INTO putnik_pickup_lokacije (putnik_ime, lat, lng, vozac_id, datum, vreme)
VALUES ('Test Testić', 45.2671, 19.8335, '223e4567-e89b-12d3-a456-426614174001', '2026-01-31', '11:00');
-- Ovo bi trebalo da padne

-- Test NOT NULL za putnik_ime
INSERT INTO putnik_pickup_lokacije (putnik_id, lat, lng, vozac_id, datum, vreme)
VALUES ('123e4567-e89b-12d3-a456-426614174000', 45.2671, 19.8335, '223e4567-e89b-12d3-a456-426614174001', '2026-01-31', '11:00');
-- Ovo bi trebalo da padne

-- Test NOT NULL za lat
INSERT INTO putnik_pickup_lokacije (putnik_id, putnik_ime, lng, vozac_id, datum, vreme)
VALUES ('123e4567-e89b-12d3-a456-426614174000', 'Test Testić', 19.8335, '223e4567-e89b-12d3-a456-426614174001', '2026-01-31', '11:00');
-- Ovo bi trebalo da padne

-- ===========================================
-- 6. TEST FILTRIRANJE PO DATUMU
-- ===========================================
SELECT putnik_ime, lat, lng, vreme
FROM putnik_pickup_lokacije
WHERE datum = '2026-01-31'
ORDER BY vreme;

-- ===========================================
-- 7. TEST FILTRIRANJE PO VOZAC-u
-- ===========================================
SELECT putnik_ime, datum, vreme, lat, lng
FROM putnik_pickup_lokacije
WHERE vozac_id = '223e4567-e89b-12d3-a456-426614174001'
ORDER BY vreme;

-- ===========================================
-- 8. TEST STATISTIKA PO DATUMU
-- ===========================================
SELECT
    datum,
    COUNT(*) as broj_pickup_lokacija,
    COUNT(DISTINCT putnik_id) as jedinstveni_putnici,
    MIN(vreme) as prvo_vreme,
    MAX(vreme) as poslednje_vreme
FROM putnik_pickup_lokacije
GROUP BY datum
ORDER BY datum DESC;

-- ===========================================
-- 9. TEST REALTIME PUBLICATION
-- ===========================================
SELECT schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
AND tablename = 'putnik_pickup_lokacije';

-- ===========================================
-- 10. CLEANUP - Briši test podatke
-- ===========================================
DELETE FROM putnik_pickup_lokacije
WHERE putnik_ime IN ('Marko Marković', 'Ana Anić', 'Petar Petrović');

-- Proveri da li je cleanup uspeo
SELECT COUNT(*) as preostalo_test_podataka
FROM putnik_pickup_lokacije
WHERE putnik_ime IN ('Marko Marković', 'Ana Anić', 'Petar Petrović');

-- ===========================================
-- KRAJ TESTOVA
-- ===========================================
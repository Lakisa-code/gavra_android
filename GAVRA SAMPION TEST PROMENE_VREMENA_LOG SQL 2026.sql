-- GAVRA SAMPION TEST PROMENE_VREMENA_LOG SQL 2026
-- Testovi za tabelu promene_vremena_log
-- Datum: 31.01.2026

-- ===========================================
-- 1. PROVERA DA LI TABELA POSTOJI
-- ===========================================
SELECT 'Tabela promene_vremena_log postoji' as status
WHERE EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'promene_vremena_log'
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
WHERE table_name = 'promene_vremena_log'
ORDER BY ordinal_position;

-- ===========================================
-- 3. TEST INSERT - OSNOVNI
-- ===========================================
INSERT INTO promene_vremena_log (putnik_id, datum, ciljni_dan, datum_polaska, sati_unapred)
VALUES
    ('123e4567-e89b-12d3-a456-426614174000', '2026-01-31', 'Ponedeljak', '2026-02-03', 48),
    ('223e4567-e89b-12d3-a456-426614174001', '2026-01-30', 'Utorak', '2026-02-04', 72),
    ('323e4567-e89b-12d3-a456-426614174002', '2026-01-29', 'Sreda', '2026-02-05', 24);

-- ===========================================
-- 4. PROVERA INSERT-ovanih podataka
-- ===========================================
SELECT id, putnik_id, datum, ciljni_dan, datum_polaska, sati_unapred, created_at
FROM promene_vremena_log
ORDER BY created_at DESC
LIMIT 5;

-- ===========================================
-- 5. TEST CONSTRAINTS
-- ===========================================
-- Test NOT NULL za putnik_id
INSERT INTO promene_vremena_log (datum, ciljni_dan, datum_polaska, sati_unapred)
VALUES ('2026-01-31', 'Ponedeljak', '2026-02-03', 48);
-- Ovo bi trebalo da padne

-- Test NOT NULL za datum
INSERT INTO promene_vremena_log (putnik_id, ciljni_dan, datum_polaska, sati_unapred)
VALUES ('123e4567-e89b-12d3-a456-426614174000', 'Ponedeljak', '2026-02-03', 48);
-- Ovo bi trebalo da padne

-- ===========================================
-- 6. TEST FILTRIRANJE PO DATUMU
-- ===========================================
SELECT id, putnik_id, datum, ciljni_dan, sati_unapred
FROM promene_vremena_log
WHERE datum >= '2026-01-30'
ORDER BY datum DESC;

-- ===========================================
-- 7. TEST STATISTIKA PO CILJNOM DANU
-- ===========================================
SELECT
    ciljni_dan,
    COUNT(*) as broj_promena,
    AVG(sati_unapred) as prosecno_sati_unapred,
    MIN(datum) as najstarija_promena,
    MAX(datum) as najnovija_promena
FROM promene_vremena_log
GROUP BY ciljni_dan
ORDER BY broj_promena DESC;

-- ===========================================
-- 8. TEST FILTRIRANJE PO SATIMA UNAPRED
-- ===========================================
SELECT id, putnik_id, datum, sati_unapred, ciljni_dan
FROM promene_vremena_log
WHERE sati_unapred >= 48
ORDER BY sati_unapred DESC;

-- ===========================================
-- 9. TEST REALTIME PUBLICATION
-- ===========================================
SELECT schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
AND tablename = 'promene_vremena_log';

-- ===========================================
-- 10. CLEANUP - Briši test podatke
-- ===========================================
DELETE FROM promene_vremena_log
WHERE putnik_id IN ('123e4567-e89b-12d3-a456-426614174000', '223e4567-e89b-12d3-a456-426614174001', '323e4567-e89b-12d3-a456-426614174002');

-- Proveri da li je cleanup uspeo
SELECT COUNT(*) as preostalo_test_podataka
FROM promene_vremena_log
WHERE putnik_id IN ('123e4567-e89b-12d3-a456-426614174000', '223e4567-e89b-12d3-a456-426614174001', '323e4567-e89b-12d3-a456-426614174002');

-- ===========================================
-- KRAJ TESTOVA
-- ===========================================
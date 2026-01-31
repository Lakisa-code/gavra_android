-- GAVRA SAMPION TEST PIN_ZAHTEVI SQL 2026
-- Testovi za tabelu pin_zahtevi
-- Datum: 31.01.2026

-- ===========================================
-- 1. PROVERA DA LI TABELA POSTOJI
-- ===========================================
SELECT 'Tabela pin_zahtevi postoji' as status
WHERE EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'pin_zahtevi'
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
WHERE table_name = 'pin_zahtevi'
ORDER BY ordinal_position;

-- ===========================================
-- 3. TEST INSERT - OSNOVNI
-- ===========================================
INSERT INTO pin_zahtevi (putnik_id, email, telefon, status)
VALUES
    ('123e4567-e89b-12d3-a456-426614174000', 'test@example.com', '+38164123456', 'pending'),
    ('223e4567-e89b-12d3-a456-426614174001', 'user@test.com', '+38164765432', 'approved'),
    ('323e4567-e89b-12d3-a456-426614174002', 'admin@gavra.com', '+38160123456', 'rejected');

-- ===========================================
-- 4. PROVERA INSERT-ovanih podataka
-- ===========================================
SELECT id, putnik_id, email, telefon, status, created_at
FROM pin_zahtevi
ORDER BY created_at DESC
LIMIT 5;

-- ===========================================
-- 5. TEST CONSTRAINTS
-- ===========================================
-- Test NOT NULL za putnik_id
INSERT INTO pin_zahtevi (email, telefon, status)
VALUES ('test@example.com', '+38164123456', 'pending');
-- Ovo bi trebalo da padne

-- Test NOT NULL za status
INSERT INTO pin_zahtevi (putnik_id, email, telefon)
VALUES ('123e4567-e89b-12d3-a456-426614174000', 'test@example.com', '+38164123456');
-- Ovo bi trebalo da padne

-- ===========================================
-- 6. TEST STATUS VREDNOSTI
-- ===========================================
SELECT DISTINCT status, COUNT(*) as broj_zahteva
FROM pin_zahtevi
GROUP BY status;

-- ===========================================
-- 7. TEST STATISTIKA PO STATUSU
-- ===========================================
SELECT
    status,
    COUNT(*) as ukupno_zahteva,
    MIN(created_at) as najstariji_zahtev,
    MAX(created_at) as najnoviji_zahtev
FROM pin_zahtevi
GROUP BY status;

-- ===========================================
-- 8. TEST FILTRIRANJE PO EMAIL-u
-- ===========================================
SELECT id, email, telefon, status, created_at
FROM pin_zahtevi
WHERE email LIKE '%@%'
ORDER BY created_at DESC;

-- ===========================================
-- 9. TEST REALTIME PUBLICATION
-- ===========================================
SELECT schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
AND tablename = 'pin_zahtevi';

-- ===========================================
-- 10. CLEANUP - Briši test podatke
-- ===========================================
DELETE FROM pin_zahtevi
WHERE email IN ('test@example.com', 'user@test.com', 'admin@gavra.com');

-- Proveri da li je cleanup uspeo
SELECT COUNT(*) as preostalo_test_podataka
FROM pin_zahtevi
WHERE email IN ('test@example.com', 'user@test.com', 'admin@gavra.com');

-- ===========================================
-- KRAJ TESTOVA
-- ===========================================
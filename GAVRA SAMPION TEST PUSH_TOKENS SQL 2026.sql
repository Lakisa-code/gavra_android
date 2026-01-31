-- GAVRA SAMPION TEST PUSH_TOKENS SQL 2026
-- Testovi za tabelu push_tokens
-- Datum: 31.01.2026

-- ===========================================
-- 1. PROVERA DA LI TABELA POSTOJI
-- ===========================================
SELECT 'Tabela push_tokens postoji' as status
WHERE EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'push_tokens'
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
WHERE table_name = 'push_tokens'
ORDER BY ordinal_position;

-- ===========================================
-- 3. TEST INSERT - OSNOVNI
-- ===========================================
INSERT INTO push_tokens (provider, token, user_id, user_type, putnik_id, vozac_id)
VALUES
    ('fcm', 'fcm_token_123', '123e4567-e89b-12d3-a456-426614174000', 'putnik', '123e4567-e89b-12d3-a456-426614174000', NULL),
    ('apns', 'apns_token_456', '223e4567-e89b-12d3-a456-426614174001', 'vozac', NULL, '223e4567-e89b-12d3-a456-426614174001'),
    ('fcm', 'fcm_token_789', '323e4567-e89b-12d3-a456-426614174002', 'putnik', '323e4567-e89b-12d3-a456-426614174002', NULL);

-- ===========================================
-- 4. PROVERA INSERT-ovanih podataka
-- ===========================================
SELECT id, provider, LEFT(token, 20) as token_preview, user_type, putnik_id, vozac_id, created_at, updated_at
FROM push_tokens
ORDER BY created_at DESC
LIMIT 5;

-- ===========================================
-- 5. TEST CONSTRAINTS
-- ===========================================
-- Test NOT NULL za provider
INSERT INTO push_tokens (token, user_id, user_type)
VALUES ('test_token', '123e4567-e89b-12d3-a456-426614174000', 'putnik');
-- Ovo bi trebalo da padne

-- Test NOT NULL za token
INSERT INTO push_tokens (provider, user_id, user_type)
VALUES ('fcm', '123e4567-e89b-12d3-a456-426614174000', 'putnik');
-- Ovo bi trebalo da padne

-- Test NOT NULL za user_id
INSERT INTO push_tokens (provider, token, user_type)
VALUES ('fcm', 'test_token', 'putnik');
-- Ovo bi trebalo da padne

-- ===========================================
-- 6. TEST FILTRIRANJE PO PROVIDER-u
-- ===========================================
SELECT provider, COUNT(*) as broj_tokena
FROM push_tokens
GROUP BY provider
ORDER BY broj_tokena DESC;

-- ===========================================
-- 7. TEST FILTRIRANJE PO USER TYPE-u
-- ===========================================
SELECT user_type, COUNT(*) as broj_korisnika
FROM push_tokens
GROUP BY user_type
ORDER BY broj_korisnika DESC;

-- ===========================================
-- 8. TEST FILTRIRANJE PO PUTNIK_ID
-- ===========================================
SELECT id, provider, user_type, putnik_id
FROM push_tokens
WHERE putnik_id IS NOT NULL
ORDER BY created_at DESC;

-- ===========================================
-- 9. TEST REALTIME PUBLICATION
-- ===========================================
SELECT schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
AND tablename = 'push_tokens';

-- ===========================================
-- 10. CLEANUP - Briši test podatke
-- ===========================================
DELETE FROM push_tokens
WHERE token IN ('fcm_token_123', 'apns_token_456', 'fcm_token_789');

-- Proveri da li je cleanup uspeo
SELECT COUNT(*) as preostalo_test_podataka
FROM push_tokens
WHERE token IN ('fcm_token_123', 'apns_token_456', 'fcm_token_789');

-- ===========================================
-- KRAJ TESTOVA
-- ===========================================
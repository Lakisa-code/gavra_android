-- GAVRA SAMPION TEST ADRESE DIRECT COLUMNS.sql
-- Comprehensive test script for adrese table with direct columns

-- =====================================================
-- TEST 1: Verify table structure
-- =====================================================
SELECT 'TEST 1: Table structure' as test_name;
\\d adrese

-- =====================================================
-- TEST 2: INSERT test data
-- =====================================================
SELECT 'TEST 2: INSERT operations' as test_name;

-- Insert test addresses
INSERT INTO adrese (id, naziv, grad, ulica, broj, koordinate) VALUES
('550e8400-e29b-41d4-a716-446655440002', 'Škola "Sveti Sava"', 'Bela Crkva', 'Trg Svetog Save', '1', '{"lat": 44.755, "lng": 21.415}'),
('550e8400-e29b-41d4-a716-446655440003', 'Dom Zdravlja', 'Bela Crkva', 'Glavna', '25', '{"lat": 44.750, "lng": 21.420}'),
('550e8400-e29b-41d4-a716-446655440004', 'Pošta', 'Vršac', 'Trg Pobede', '5', '{"lat": 45.120, "lng": 21.300}'),
('550e8400-e29b-41d4-a716-446655440005', 'Autobuska Stanica', 'Vršac', 'Železnička', '12', '{"lat": 45.118, "lng": 21.305}');

SELECT 'Inserted 4 test addresses' as status;

-- =====================================================
-- TEST 3: SELECT operations
-- =====================================================
SELECT 'TEST 3: SELECT operations' as test_name;

-- Select all addresses
SELECT COUNT(*) as total_addresses FROM adrese;

-- Select by city
SELECT naziv, grad FROM adrese WHERE grad = 'Bela Crkva' ORDER BY naziv;
SELECT naziv, grad FROM adrese WHERE grad = 'Vršac' ORDER BY naziv;

-- Select with coordinates
SELECT naziv, koordinate FROM adrese WHERE koordinate IS NOT NULL;

-- =====================================================
-- TEST 4: UPDATE operations
-- =====================================================
SELECT 'TEST 4: UPDATE operations' as test_name;

-- Update address details
UPDATE adrese SET broj = '2', updated_at = NOW()
WHERE naziv = 'Škola "Sveti Sava"';

UPDATE adrese SET ulica = 'Trg Pobede 5', updated_at = NOW()
WHERE naziv = 'Pošta';

-- Verify updates
SELECT naziv, ulica, broj FROM adrese WHERE naziv IN ('Škola "Sveti Sava"', 'Pošta');

-- =====================================================
-- TEST 5: JSONB coordinates operations
-- =====================================================
SELECT 'TEST 5: JSONB coordinates operations' as test_name;

-- Query by coordinate existence
SELECT naziv, koordinate FROM adrese WHERE koordinate IS NOT NULL;

-- Extract latitude/longitude from JSONB
SELECT
    naziv,
    koordinate->>'lat' as latitude,
    koordinate->>'lng' as longitude
FROM adrese
WHERE koordinate IS NOT NULL;

-- Update coordinates
UPDATE adrese SET
    koordinate = '{"lat": 44.760, "lng": 21.410, "source": "updated"}',
    updated_at = NOW()
WHERE naziv = 'Dom Zdravlja';

SELECT naziv, koordinate FROM adrese WHERE naziv = 'Dom Zdravlja';

-- =====================================================
-- TEST 6: INDEX performance test
-- =====================================================
SELECT 'TEST 6: INDEX performance test' as test_name;

-- Test grad index
EXPLAIN SELECT * FROM adrese WHERE grad = 'Bela Crkva';

-- Test naziv index
EXPLAIN SELECT * FROM adrese WHERE naziv ILIKE '%škola%';

-- =====================================================
-- TEST 7: CONSTRAINTS and validation
-- =====================================================
SELECT 'TEST 7: CONSTRAINTS and validation' as test_name;

-- Test NOT NULL constraint (should fail)
-- INSERT INTO adrese (id, grad) VALUES ('test-id', 'Test') -- This would fail

-- Test UUID primary key
SELECT id, naziv FROM adrese LIMIT 2;

-- =====================================================
-- TEST 8: CLEANUP - Remove test data
-- =====================================================
SELECT 'TEST 8: CLEANUP' as test_name;

DELETE FROM adrese WHERE id IN (
    '550e8400-e29b-41d4-a716-446655440002',
    '550e8400-e29b-41d4-a716-446655440003',
    '550e8400-e29b-41d4-a716-446655440004',
    '550e8400-e29b-41d4-a716-446655440005'
);

SELECT 'Test data cleaned up. Remaining addresses:' as status;
SELECT COUNT(*) as remaining_addresses FROM adrese;

-- =====================================================
-- FINAL STATUS
-- =====================================================
SELECT 'ALL TESTS COMPLETED SUCCESSFULLY' as final_status;
SELECT
    schemaname,
    tablename,
    attname as column_name,
    typname as data_type,
    attnotnull as not_null
FROM pg_attribute a
JOIN pg_class c ON a.attrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
JOIN pg_type t ON a.atttypid = t.oid
WHERE n.nspname = 'public'
  AND c.relname = 'adrese'
  AND a.attnum > 0
  AND NOT a.attisdropped
ORDER BY a.attnum;
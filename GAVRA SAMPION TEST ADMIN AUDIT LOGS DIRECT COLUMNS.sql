-- GAVRA SAMPION TEST ADMIN AUDIT LOGS DIRECT COLUMNS v2.0
-- Testira admin_audit_logs tabelu sa DIREKTNIM KOLONAMA (ne JSONB)
-- Datum: 31.01.2026

-- =====================================================
-- TEST 1: PROVERA POSTOJANJA TABELE
-- =====================================================

-- Proveri da li tabela postoji i ima 9 kolona
SELECT
    schemaname,
    tablename,
    tableowner
FROM pg_tables
WHERE tablename = 'admin_audit_logs';

-- =====================================================
-- TEST 2: PROVERA ŠEME (9 KOLONA)
-- =====================================================

-- Prikaži sve kolone u tabeli
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'admin_audit_logs'
ORDER BY ordinal_position;

-- =====================================================
-- TEST 3: INSERT SA DIREKTNIM KOLONAMA
-- =====================================================

-- INSERT test podataka sa DIREKTNIM KOLONAMA
INSERT INTO admin_audit_logs
(admin_name, action_type, details, inventory_liters, total_debt, severity, metadata)
VALUES
('system_test_v2', 'DIRECT_COLUMNS_TEST_V2', 'Test direktnih kolona v2.0',
 2468.12, 135790.24, 'medium',
 '{"test_version": "2.0", "test_type": "direct_columns", "created_by": "GAVRA_SAMPION"}')
RETURNING id, created_at, inventory_liters, total_debt, severity;

-- =====================================================
-- TEST 4: SELECT DIREKTNIH KOLONA
-- =====================================================

-- SELECT test podataka sa fokusom na DIREKTNE KOLONE
SELECT
    id,
    admin_name,
    action_type,
    inventory_liters,  -- DIREKTNA DECIMAL KOLONA
    total_debt,        -- DIREKTNA DECIMAL KOLONA
    severity,          -- DIREKTNA VARCHAR KOLONA
    created_at
FROM admin_audit_logs
WHERE admin_name = 'system_test_v2'
ORDER BY created_at DESC
LIMIT 5;

-- =====================================================
-- TEST 5: UPDATE DIREKTNIH KOLONA
-- =====================================================

-- UPDATE test podataka - menjamo DIREKTNE KOLONE
UPDATE admin_audit_logs
SET
    inventory_liters = inventory_liters + 1000.00,  -- Povećaj za 1000L
    total_debt = total_debt - 5000.00,              -- Smanji za 5000
    severity = 'high'                               -- Promeni ozbiljnost
WHERE admin_name = 'system_test_v2'
RETURNING id, inventory_liters, total_debt, severity;

-- =====================================================
-- TEST 6: UPITI ZA PERFORMANSE DIREKTNIH KOLONA
-- =====================================================

-- Upit sa WHERE klauzulom na DIREKTNOJ KOLONI (brže od JSONB)
SELECT
    id,
    admin_name,
    action_type,
    inventory_liters,
    total_debt,
    severity
FROM admin_audit_logs
WHERE inventory_liters > 2000.00
  AND severity = 'high'
ORDER BY created_at DESC;

-- Agregacija na DIREKTNOJ KOLONI (brže od JSONB parsing)
SELECT
    COUNT(*) as total_records,
    AVG(inventory_liters) as avg_inventory,
    SUM(total_debt) as total_debt_sum,
    MIN(severity) as min_severity,
    MAX(severity) as max_severity
FROM admin_audit_logs
WHERE admin_name LIKE 'system%';

-- =====================================================
-- TEST 7: ČIŠĆENJE TEST PODATAKA
-- =====================================================

-- Obrisi test podatke
DELETE FROM admin_audit_logs
WHERE admin_name = 'system_test_v2'
RETURNING id, admin_name, action_type;

-- =====================================================
-- TEST 8: PROVERA INDEKSA NA DIREKTNIM KOLONAMA
-- =====================================================

-- Proveri da li indeksi postoje na direktnim kolonama
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'admin_audit_logs'
  AND (indexname LIKE '%inventory%' OR
       indexname LIKE '%total_debt%' OR
       indexname LIKE '%severity%');

-- =====================================================
-- TEST 9: UPREDI PERFORMANSE - DIREKTNE vs JSONB
-- =====================================================

-- INSERT sa JSONB pristupom (stari način) - samo za poređenje
INSERT INTO admin_audit_logs
(admin_name, action_type, details, metadata)
VALUES
('system_jsonb_test', 'JSONB_COMPARISON', 'Upoređenje sa JSONB',
 '{"inventory_liters": 1111.11, "total_debt": 22222.22, "severity": "low"}');

-- SELECT sa JSONB pristupom (stari način)
SELECT
    id,
    admin_name,
    metadata->>'inventory_liters' as jsonb_inventory,
    metadata->>'total_debt' as jsonb_debt,
    metadata->>'severity' as jsonb_severity
FROM admin_audit_logs
WHERE admin_name = 'system_jsonb_test';

-- SELECT sa DIREKTNIM KOLONAMA (novi način)
SELECT
    id,
    admin_name,
    inventory_liters as direct_inventory,
    total_debt as direct_debt,
    severity as direct_severity
FROM admin_audit_logs
WHERE admin_name = 'system_test_v2'
ORDER BY created_at DESC
LIMIT 1;

-- Obrisi JSONB test podatke
DELETE FROM admin_audit_logs
WHERE admin_name = 'system_jsonb_test';

-- =====================================================
-- TEST 10: FINALNA PROVERA STANJA TABELE
-- =====================================================

-- Broj ukupnih zapisa
SELECT COUNT(*) as total_records FROM admin_audit_logs;

-- Provera da li su sve DIREKTNE KOLONE popunjene
SELECT
    COUNT(*) as total_records,
    COUNT(inventory_liters) as records_with_inventory,
    COUNT(total_debt) as records_with_debt,
    COUNT(severity) as records_with_severity,
    COUNT(metadata) as records_with_metadata
FROM admin_audit_logs;

-- Najnoviji zapis sa DIREKTNIM KOLONAMA
SELECT
    id,
    admin_name,
    action_type,
    inventory_liters,
    total_debt,
    severity,
    created_at
FROM admin_audit_logs
ORDER BY created_at DESC
LIMIT 1;

-- =====================================================
-- KRAJ TESTA - GAVRA SAMPION DIREKTNE KOLONE v2.0
-- =====================================================
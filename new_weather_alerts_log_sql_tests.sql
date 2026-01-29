-- ULTRA-DETAJNI SQL TESTOVI ZA weather_alerts_log TABELU
-- Kreirano od strane GitHub Copilot - Januar 2026
-- 20 ultra-detaljnih upita za kompletnu validaciju

-- ==========================================
-- 1. SCHEMA INTEGRITY TESTS
-- ==========================================

-- Test 1: Provera postojanja tabele
SELECT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name = 'weather_alerts_log'
) as table_exists;

-- Test 2: Detaljna šema tabele
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'weather_alerts_log'
ORDER BY ordinal_position;

-- Test 3: Provera constraints
SELECT
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
LEFT JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
WHERE tc.table_schema = 'public'
AND tc.table_name = 'weather_alerts_log';

-- ==========================================
-- 2. DATA TYPE VALIDATION TESTS
-- ==========================================

-- Test 4: Validacija UUID formata za ID
SELECT
    COUNT(*) as total_rows,
    COUNT(id) as non_null_ids,
    COUNT(DISTINCT id) as unique_ids
FROM weather_alerts_log;

-- Test 5: Validacija DATE formata za alert_date
SELECT
    alert_date,
    COUNT(*) as count_per_date
FROM weather_alerts_log
WHERE alert_date IS NOT NULL
GROUP BY alert_date
ORDER BY alert_date DESC
LIMIT 10;

-- Test 6: Validacija TEXT formata za alert_types
SELECT
    LENGTH(alert_types) as text_length,
    COUNT(*) as count_per_length
FROM weather_alerts_log
WHERE alert_types IS NOT NULL
GROUP BY LENGTH(alert_types)
ORDER BY LENGTH(alert_types);

-- Test 7: Validacija TIMESTAMP formata za created_at
SELECT
    created_at,
    EXTRACT(YEAR FROM created_at) as year,
    EXTRACT(MONTH FROM created_at) as month,
    COUNT(*) as count_per_month
FROM weather_alerts_log
WHERE created_at IS NOT NULL
GROUP BY EXTRACT(YEAR FROM created_at), EXTRACT(MONTH FROM created_at), created_at
ORDER BY created_at DESC
LIMIT 10;

-- ==========================================
-- 3. CONSTRAINT VALIDATION TESTS
-- ==========================================

-- Test 8: Provera NOT NULL constraints
SELECT
    'id' as column_name,
    COUNT(*) as total_rows,
    SUM(CASE WHEN id IS NULL THEN 1 ELSE 0 END) as null_count
FROM weather_alerts_log
UNION ALL
SELECT
    'alert_date' as column_name,
    COUNT(*) as total_rows,
    SUM(CASE WHEN alert_date IS NULL THEN 1 ELSE 0 END) as null_count
FROM weather_alerts_log;

-- Test 9: Provera NULLABLE constraints
SELECT
    'alert_types' as column_name,
    COUNT(*) as total_rows,
    SUM(CASE WHEN alert_types IS NULL THEN 1 ELSE 0 END) as null_count
FROM weather_alerts_log
UNION ALL
SELECT
    'created_at' as column_name,
    COUNT(*) as total_rows,
    SUM(CASE WHEN created_at IS NULL THEN 1 ELSE 0 END) as null_count
FROM weather_alerts_log;

-- Test 10: Provera DEFAULT vrednosti
SELECT
    COUNT(*) as total_rows,
    COUNT(CASE WHEN created_at IS NOT NULL THEN 1 END) as created_at_populated
FROM weather_alerts_log;

-- ==========================================
-- 4. DATA INTEGRITY TESTS
-- ==========================================

-- Test 11: Provera jedinstvenosti ID-a
SELECT
    id,
    COUNT(*) as occurrence_count
FROM weather_alerts_log
GROUP BY id
HAVING COUNT(*) > 1;

-- Test 12: Provera validnosti datuma (ne u budućnosti)
SELECT
    alert_date,
    CASE WHEN alert_date > CURRENT_DATE THEN 'FUTURE_DATE' ELSE 'VALID_DATE' END as date_status
FROM weather_alerts_log
WHERE alert_date IS NOT NULL
ORDER BY alert_date DESC
LIMIT 5;

-- Test 13: Provera konzistentnosti created_at (ne u budućnosti)
SELECT
    created_at,
    CASE WHEN created_at > NOW() THEN 'FUTURE_TIMESTAMP' ELSE 'VALID_TIMESTAMP' END as timestamp_status
FROM weather_alerts_log
WHERE created_at IS NOT NULL
ORDER BY created_at DESC
LIMIT 5;

-- ==========================================
-- 5. BUSINESS LOGIC TESTS
-- ==========================================

-- Test 14: Analiza tipova alert-a
SELECT
    alert_types,
    COUNT(*) as frequency,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM weather_alerts_log
WHERE alert_types IS NOT NULL
GROUP BY alert_types
ORDER BY frequency DESC;

-- Test 15: Analiza alert-a po datumima
SELECT
    alert_date,
    COUNT(*) as alerts_per_day,
    STRING_AGG(DISTINCT alert_types, ', ') as alert_types_per_day
FROM weather_alerts_log
WHERE alert_date IS NOT NULL
GROUP BY alert_date
ORDER BY alert_date DESC
LIMIT 10;

-- Test 16: Provera da li su alert-i logovani na vreme
SELECT
    alert_date,
    created_at,
    EXTRACT(EPOCH FROM (created_at - alert_date)) / 86400 as days_difference
FROM weather_alerts_log
WHERE alert_date IS NOT NULL AND created_at IS NOT NULL
ORDER BY days_difference DESC
LIMIT 10;

-- ==========================================
-- 6. STATISTICS AND ANALYTICS TESTS
-- ==========================================

-- Test 17: Osnovne statistike tabele
SELECT
    'weather_alerts_log' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT id) as unique_ids,
    COUNT(DISTINCT alert_date) as unique_dates,
    MIN(alert_date) as earliest_alert,
    MAX(alert_date) as latest_alert,
    MIN(created_at) as earliest_created,
    MAX(created_at) as latest_created
FROM weather_alerts_log;

-- Test 18: Statistika NULL vrednosti po koloni
SELECT
    'id' as column_name, SUM(CASE WHEN id IS NULL THEN 1 ELSE 0 END) as null_count, COUNT(*) as total_count
FROM weather_alerts_log
UNION ALL
SELECT 'alert_date', SUM(CASE WHEN alert_date IS NULL THEN 1 ELSE 0 END), COUNT(*)
FROM weather_alerts_log
UNION ALL
SELECT 'alert_types', SUM(CASE WHEN alert_types IS NULL THEN 1 ELSE 0 END), COUNT(*)
FROM weather_alerts_log
UNION ALL
SELECT 'created_at', SUM(CASE WHEN created_at IS NULL THEN 1 ELSE 0 END), COUNT(*)
FROM weather_alerts_log;

-- Test 19: Analiza distribucije podataka
SELECT
    EXTRACT(YEAR FROM alert_date) as year,
    EXTRACT(MONTH FROM alert_date) as month,
    COUNT(*) as alerts_per_month
FROM weather_alerts_log
WHERE alert_date IS NOT NULL
GROUP BY EXTRACT(YEAR FROM alert_date), EXTRACT(MONTH FROM alert_date)
ORDER BY year DESC, month DESC
LIMIT 12;

-- ==========================================
-- 7. PERFORMANCE TESTS
-- ==========================================

-- Test 20: Provera indeksa
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'weather_alerts_log'
ORDER BY indexname;

-- Dodatni performance testovi (ako je potrebno)
-- EXPLAIN ANALYZE SELECT * FROM weather_alerts_log WHERE alert_date >= CURRENT_DATE - INTERVAL '30 days';
-- EXPLAIN ANALYZE SELECT COUNT(*) FROM weather_alerts_log GROUP BY alert_date;
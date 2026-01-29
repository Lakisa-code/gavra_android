-- =====================================================
-- NOVI SQL TESTOVI ZA app_config TABELU
-- Kreirano od strane GitHub Copilot - Januar 2026
-- =====================================================

-- TEST 1: Osnovne informacije o tabeli
SELECT
    'app_config' as table_name,
    COUNT(*) as total_configs,
    COUNT(DISTINCT key) as unique_keys,
    MAX(updated_at) as last_update,
    MIN(updated_at) as first_update
FROM app_config;

-- TEST 2: Struktura tabele
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default,
    CASE
        WHEN column_name IN ('key', 'value') THEN 'REQUIRED'
        ELSE 'OPTIONAL'
    END as constraint_type
FROM information_schema.columns
WHERE table_name = 'app_config'
ORDER BY ordinal_position;

-- TEST 3: Prikaz svih konfiguracija
SELECT
    key,
    value,
    description,
    updated_at,
    CASE
        WHEN key = 'default_capacity' THEN 'VEHICLE'
        WHEN key = 'squeeze_in_limit' THEN 'BUSINESS_LOGIC'
        WHEN key = 'cancel_limit_hours' THEN 'POLICY'
        ELSE 'OTHER'
    END as config_category
FROM app_config
ORDER BY updated_at DESC;

-- TEST 4: Validacija numeričkih vrednosti
SELECT
    'Numeric Validation' as validation_type,
    key,
    value,
    CASE
        WHEN value ~ '^[0-9]+$' THEN 'VALID_INTEGER'
        WHEN value ~ '^[0-9]+\.[0-9]+$' THEN 'VALID_DECIMAL'
        ELSE 'INVALID_FORMAT'
    END as validation_result,
    CASE
        WHEN key = 'default_capacity' AND value::integer BETWEEN 10 AND 50 THEN 'REASONABLE'
        WHEN key = 'squeeze_in_limit' AND value::integer BETWEEN 1 AND 10 THEN 'REASONABLE'
        WHEN key = 'cancel_limit_hours' AND value::integer BETWEEN 1 AND 24 THEN 'REASONABLE'
        ELSE 'OUT_OF_RANGE'
    END as range_check
FROM app_config
ORDER BY key;

-- TEST 5: Provera poslovne logike
SELECT
    'Business Logic Check' as check_type,
    (SELECT value::integer FROM app_config WHERE key = 'default_capacity') as default_capacity,
    (SELECT value::integer FROM app_config WHERE key = 'squeeze_in_limit') as squeeze_in_limit,
    CASE
        WHEN (SELECT value::integer FROM app_config WHERE key = 'squeeze_in_limit') <
             (SELECT value::integer FROM app_config WHERE key = 'default_capacity')
        THEN 'LOGIC_OK'
        ELSE 'LOGIC_ERROR'
    END as logic_status,
    CASE
        WHEN (SELECT value::integer FROM app_config WHERE key = 'cancel_limit_hours') BETWEEN 1 AND 24
        THEN 'POLICY_OK'
        ELSE 'POLICY_ERROR'
    END as policy_status;

-- TEST 6: Analiza dužine opisa
SELECT
    'Description Analysis' as analysis_type,
    key,
    LENGTH(description) as description_length,
    CASE
        WHEN LENGTH(description) > 20 THEN 'GOOD'
        WHEN LENGTH(description) > 10 THEN 'ADEQUATE'
        ELSE 'TOO_SHORT'
    END as description_quality
FROM app_config
ORDER BY LENGTH(description) DESC;

-- TEST 7: Provera NULL vrednosti
SELECT
    'NULL Values Check' as check_type,
    COUNT(*) as total_configs,
    COUNT(CASE WHEN key IS NULL THEN 1 END) as null_keys,
    COUNT(CASE WHEN value IS NULL THEN 1 END) as null_values,
    COUNT(CASE WHEN description IS NULL THEN 1 END) as null_descriptions,
    COUNT(CASE WHEN updated_at IS NULL THEN 1 END) as null_timestamps,
    CASE
        WHEN COUNT(CASE WHEN key IS NULL THEN 1 END) = 0
             AND COUNT(CASE WHEN value IS NULL THEN 1 END) = 0
        THEN 'INTEGRITY_OK'
        ELSE 'INTEGRITY_ISSUES'
    END as integrity_status
FROM app_config;

-- TEST 8: Duplikati provera
SELECT
    'Duplicate Check' as check_type,
    COUNT(*) as total_configs,
    COUNT(DISTINCT key) as unique_keys,
    (COUNT(*) - COUNT(DISTINCT key)) as duplicate_keys,
    CASE
        WHEN (COUNT(*) - COUNT(DISTINCT key)) = 0 THEN 'NO_DUPLICATES'
        ELSE 'DUPLICATES_FOUND'
    END as duplicate_status
FROM app_config;

-- TEST 9: Vremenska analiza
SELECT
    'Time Analysis' as analysis_type,
    key,
    updated_at,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - updated_at))/86400 as days_since_update,
    CASE
        WHEN EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - updated_at))/86400 < 1 THEN 'RECENT'
        WHEN EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - updated_at))/86400 < 7 THEN 'THIS_WEEK'
        WHEN EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - updated_at))/86400 < 30 THEN 'THIS_MONTH'
        ELSE 'OLDER'
    END as update_category
FROM app_config
ORDER BY updated_at DESC;

-- TEST 10: Pretraga po ključu
SELECT
    key,
    value,
    description
FROM app_config
WHERE key ILIKE '%capacity%' OR key ILIKE '%limit%' OR key ILIKE '%cancel%'
ORDER BY key;

-- TEST 11: Statistika vrednosti
SELECT
    'Value Statistics' as stats_type,
    AVG(value::numeric) as avg_numeric_value,
    MIN(value::numeric) as min_value,
    MAX(value::numeric) as max_value,
    STDDEV(value::numeric) as value_stddev,
    COUNT(CASE WHEN value::numeric > 10 THEN 1 END) as high_values,
    COUNT(CASE WHEN value::numeric <= 10 THEN 1 END) as low_values
FROM app_config
WHERE value ~ '^[0-9]+(\.[0-9]+)?$';

-- TEST 12: Provera konzistentnosti
SELECT
    'Consistency Check' as check_type,
    key,
    value,
    description,
    CASE
        WHEN key = 'default_capacity' AND description ILIKE '%mesta%' THEN 'CONSISTENT'
        WHEN key = 'squeeze_in_limit' AND description ILIKE '%putnika%' THEN 'CONSISTENT'
        WHEN key = 'cancel_limit_hours' AND description ILIKE '%sati%' THEN 'CONSISTENT'
        ELSE 'INCONSISTENT'
    END as key_description_match
FROM app_config;

-- TEST 13: Performance test - brzo čitanje
EXPLAIN (ANALYZE, VERBOSE, COSTS, BUFFERS, TIMING)
SELECT
    key,
    value,
    description
FROM app_config
WHERE key = 'default_capacity';

-- TEST 14: Preporuke za optimizaciju
SELECT
    'Optimization Recommendations' as recommendation_type,
    CASE
        WHEN (SELECT COUNT(*) FROM app_config) < 100 THEN 'NO_INDEX_NEEDED'
        ELSE 'CONSIDER_KEY_INDEX'
    END as indexing,
    CASE
        WHEN (SELECT MAX(updated_at) FROM app_config) < CURRENT_TIMESTAMP - INTERVAL '30 days' THEN 'STABLE_CONFIG'
        ELSE 'ACTIVE_CONFIG'
    END as stability,
    CASE
        WHEN (SELECT COUNT(*) FROM app_config WHERE description IS NULL) = 0 THEN 'GOOD_DOCUMENTATION'
        ELSE 'IMPROVE_DOCUMENTATION'
    END as documentation;

-- TEST 15: Backup i recovery provera
SELECT
    schemaname,
    tablename,
    tableowner,
    tablespace,
    hasindexes,
    hasrules,
    hastriggers,
    rowsecurity
FROM pg_tables
WHERE tablename = 'app_config';

-- TEST 16: Analiza kategorija konfiguracija
SELECT
    CASE
        WHEN key LIKE '%capacity%' THEN 'VEHICLE_CONFIG'
        WHEN key LIKE '%limit%' THEN 'BUSINESS_RULES'
        WHEN key LIKE '%cancel%' THEN 'POLICY_CONFIG'
        ELSE 'OTHER_CONFIG'
    END as config_category,
    COUNT(*) as configs_in_category,
    STRING_AGG(key, ', ') as config_keys
FROM app_config
GROUP BY CASE
    WHEN key LIKE '%capacity%' THEN 'VEHICLE_CONFIG'
    WHEN key LIKE '%limit%' THEN 'BUSINESS_RULES'
    WHEN key LIKE '%cancel%' THEN 'POLICY_CONFIG'
    ELSE 'OTHER_CONFIG'
END;

-- TEST 17: Trendovi promena
WITH config_history AS (
    SELECT
        key,
        updated_at,
        ROW_NUMBER() OVER (PARTITION BY key ORDER BY updated_at DESC) as change_rank
    FROM app_config
)
SELECT
    key,
    updated_at,
    change_rank,
    CASE
        WHEN change_rank = 1 THEN 'LATEST'
        ELSE 'OLDER'
    END as version_status
FROM config_history
ORDER BY key, updated_at DESC;

-- TEST 18: Validacija opsega vrednosti
SELECT
    'Range Validation' as validation_type,
    key,
    value::numeric as numeric_value,
    CASE
        WHEN key = 'default_capacity' AND value::numeric BETWEEN 8 AND 60 THEN 'VALID_RANGE'
        WHEN key = 'squeeze_in_limit' AND value::numeric BETWEEN 1 AND 20 THEN 'VALID_RANGE'
        WHEN key = 'cancel_limit_hours' AND value::numeric BETWEEN 0.5 AND 48 THEN 'VALID_RANGE'
        ELSE 'INVALID_RANGE'
    END as range_status,
    CASE
        WHEN key = 'default_capacity' THEN '8-60 seats'
        WHEN key = 'squeeze_in_limit' THEN '1-20 passengers'
        WHEN key = 'cancel_limit_hours' THEN '0.5-48 hours'
    END as expected_range
FROM app_config
ORDER BY key;

-- TEST 19: Kompletan pregled sistema
SELECT
    'SYSTEM OVERVIEW' as overview_type,
    (SELECT COUNT(*) FROM app_config) as total_configs,
    (SELECT COUNT(*) FROM app_config WHERE value ~ '^[0-9]+$') as numeric_configs,
    (SELECT COUNT(*) FROM app_config WHERE description IS NOT NULL) as documented_configs,
    (SELECT EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - MAX(updated_at)))/86400 FROM app_config) as days_since_last_change,
    CASE
        WHEN (SELECT COUNT(*) FROM app_config) = 3
             AND (SELECT COUNT(*) FROM app_config WHERE value ~ '^[0-9]+$') = 3
             AND (SELECT COUNT(*) FROM app_config WHERE description IS NOT NULL) = 3
        THEN 'SYSTEM_HEALTHY'
        ELSE 'SYSTEM_NEEDS_ATTENTION'
    END as system_status;

-- TEST 20: Završni status provera
SELECT
    CASE WHEN COUNT(*) > 0 THEN '✅ TABLE EXISTS' ELSE '❌ TABLE MISSING' END as table_status,
    CASE WHEN SUM(CASE WHEN key IS NOT NULL THEN 1 ELSE 0 END) = COUNT(*) THEN '✅ KEYS COMPLETE' ELSE '❌ MISSING KEYS' END as key_completeness,
    CASE WHEN SUM(CASE WHEN value IS NOT NULL THEN 1 ELSE 0 END) = COUNT(*) THEN '✅ VALUES COMPLETE' ELSE '❌ MISSING VALUES' END as value_completeness,
    CASE WHEN COUNT(DISTINCT key) = COUNT(*) THEN '✅ UNIQUE KEYS' ELSE '❌ DUPLICATE KEYS' END as uniqueness,
    CASE WHEN AVG(CASE WHEN value ~ '^[0-9]+$' THEN value::integer ELSE NULL END) > 0 THEN '✅ VALID NUMBERS' ELSE '❌ INVALID VALUES' END as validation_status
FROM app_config;
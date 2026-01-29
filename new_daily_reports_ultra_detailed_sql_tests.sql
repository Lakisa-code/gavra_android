-- =====================================================
-- ULTRA-DETAJNI SQL TESTOVI ZA daily_reports TABELU
-- NAJDETAJNIJA ANALIZA SVAKE KOLONE POJEDINAČNO
-- Kreirano od strane GitHub Copilot - Januar 2026
-- =====================================================

-- TEST 1: OSNOVNE INFORMACIJE I STRUKTURA TABELE
SELECT
    'daily_reports' as table_name,
    COUNT(*) as total_reports,
    COUNT(DISTINCT id) as unique_ids,
    COUNT(DISTINCT vozac) as unique_drivers,
    COUNT(DISTINCT vozac_id) as unique_driver_ids,
    MIN(datum) as earliest_date,
    MAX(datum) as latest_date,
    MIN(created_at) as first_created,
    MAX(created_at) as last_created
FROM daily_reports;

-- TEST 2: ULTRA-DETAJLNA STRUKTURA SVAKE KOLONE
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default,
    CASE
        WHEN column_name = 'id' THEN 'PRIMARY_KEY_UUID'
        WHEN column_name = 'vozac' THEN 'DRIVER_NAME_TEXT'
        WHEN column_name = 'datum' THEN 'REPORT_DATE'
        WHEN column_name IN ('ukupan_pazar', 'sitan_novac', 'kilometraza') THEN 'FINANCIAL_NUMERIC'
        WHEN column_name IN ('otkazani_putnici', 'naplaceni_putnici', 'pokupljeni_putnici', 'dugovi_putnici', 'mesecne_karte') THEN 'PASSENGER_COUNT_INTEGER'
        WHEN column_name IN ('checkin_vreme', 'created_at') THEN 'TIMESTAMP_WITH_TZ'
        WHEN column_name = 'automatski_generisan' THEN 'AUTO_GENERATION_FLAG'
        WHEN column_name = 'vozac_id' THEN 'FOREIGN_KEY_DRIVER'
        ELSE 'OTHER'
    END as column_category,
    CASE
        WHEN is_nullable = 'NO' THEN 'MANDATORY'
        WHEN column_default IS NOT NULL THEN 'OPTIONAL_WITH_DEFAULT'
        ELSE 'OPTIONAL_NO_DEFAULT'
    END as nullability_category
FROM information_schema.columns
WHERE table_name = 'daily_reports'
ORDER BY ordinal_position;

-- TEST 3: DETALJNA ANALIZA ID KOLONE (UUID PRIMARY KEY)
SELECT
    'ID Column Ultra Analysis' as analysis_type,
    COUNT(*) as total_ids,
    COUNT(DISTINCT id) as unique_ids,
    CASE WHEN COUNT(*) = COUNT(DISTINCT id) THEN 'ALL_UNIQUE' ELSE 'DUPLICATES_FOUND' END as uniqueness_status,
    COUNT(CASE WHEN id IS NULL THEN 1 END) as null_ids,
    MIN(LENGTH(id::text)) as min_uuid_length,
    MAX(LENGTH(id::text)) as max_uuid_length,
    AVG(LENGTH(id::text)) as avg_uuid_length,
    CASE WHEN MIN(LENGTH(id::text)) = 36 AND MAX(LENGTH(id::text)) = 36 THEN 'STANDARD_UUID_FORMAT' ELSE 'NON_STANDARD_FORMAT' END as format_status
FROM daily_reports;

-- TEST 4: DETALJNA ANALIZA VOZAC KOLONE (TEXT NOT NULL)
SELECT
    'VOZAC Column Ultra Analysis' as analysis_type,
    COUNT(DISTINCT vozac) as unique_driver_names,
    COUNT(*) as total_reports,
    COUNT(CASE WHEN vozac IS NULL THEN 1 END) as null_driver_names,
    MIN(LENGTH(vozac)) as min_name_length,
    MAX(LENGTH(vozac)) as max_name_length,
    AVG(LENGTH(vozac)) as avg_name_length,
    STRING_AGG(DISTINCT vozac, ', ') as all_driver_names,
    CASE WHEN COUNT(CASE WHEN vozac IS NULL THEN 1 END) = 0 THEN 'ALL_NAMES_PRESENT' ELSE 'MISSING_NAMES' END as completeness_status
FROM daily_reports;

-- TEST 5: DETALJNA ANALIZA DATUM KOLONE (DATE NOT NULL)
SELECT
    'DATUM Column Ultra Analysis' as analysis_type,
    COUNT(DISTINCT datum) as unique_dates,
    MIN(datum) as earliest_date,
    MAX(datum) as latest_date,
    MAX(datum) - MIN(datum) as date_range_days,
    COUNT(CASE WHEN datum IS NULL THEN 1 END) as null_dates,
    COUNT(CASE WHEN datum > CURRENT_DATE THEN 1 END) as future_dates,
    COUNT(CASE WHEN datum < CURRENT_DATE - INTERVAL '1 year' THEN 1 END) as old_dates,
    CASE
        WHEN COUNT(CASE WHEN datum IS NULL THEN 1 END) = 0 THEN 'ALL_DATES_PRESENT'
        ELSE 'MISSING_DATES'
    END as completeness_status,
    CASE
        WHEN COUNT(CASE WHEN datum > CURRENT_DATE THEN 1 END) = 0 THEN 'NO_FUTURE_DATES'
        ELSE 'FUTURE_DATES_EXIST'
    END as validity_status
FROM daily_reports;

-- TEST 6: DETALJNA ANALIZA FINANSIJSKIH KOLONA (NUMERIC)
SELECT
    'Financial Columns Ultra Analysis' as analysis_type,
    'ukupan_pazar' as column_name,
    COUNT(CASE WHEN ukupan_pazar IS NULL THEN 1 END) as null_count,
    MIN(ukupan_pazar) as min_value,
    MAX(ukupan_pazar) as max_value,
    AVG(ukupan_pazar) as avg_value,
    STDDEV(ukupan_pazar) as stddev_value,
    COUNT(CASE WHEN ukupan_pazar < 0 THEN 1 END) as negative_values,
    COUNT(CASE WHEN ukupan_pazar = 0 THEN 1 END) as zero_values,
    COUNT(CASE WHEN ukupan_pazar > 10000 THEN 1 END) as high_values
FROM daily_reports
UNION ALL
SELECT
    'Financial Columns Ultra Analysis' as analysis_type,
    'sitan_novac' as column_name,
    COUNT(CASE WHEN sitan_novac IS NULL THEN 1 END) as null_count,
    MIN(sitan_novac) as min_value,
    MAX(sitan_novac) as max_value,
    AVG(sitan_novac) as avg_value,
    STDDEV(sitan_novac) as stddev_value,
    COUNT(CASE WHEN sitan_novac < 0 THEN 1 END) as negative_values,
    COUNT(CASE WHEN sitan_novac = 0 THEN 1 END) as zero_values,
    COUNT(CASE WHEN sitan_novac > 1000 THEN 1 END) as high_values
FROM daily_reports
UNION ALL
SELECT
    'Financial Columns Ultra Analysis' as analysis_type,
    'kilometraza' as column_name,
    COUNT(CASE WHEN kilometraza IS NULL THEN 1 END) as null_count,
    MIN(kilometraza) as min_value,
    MAX(kilometraza) as max_value,
    AVG(kilometraza) as avg_value,
    STDDEV(kilometraza) as stddev_value,
    COUNT(CASE WHEN kilometraza < 0 THEN 1 END) as negative_values,
    COUNT(CASE WHEN kilometraza = 0 THEN 1 END) as zero_values,
    COUNT(CASE WHEN kilometraza > 1000 THEN 1 END) as high_values
FROM daily_reports;

-- TEST 7: DETALJNA ANALIZA PUTNIK KOLONA (INTEGER)
SELECT
    'Passenger Columns Ultra Analysis' as analysis_type,
    column_name,
    COUNT(CASE WHEN value IS NULL THEN 1 END) as null_count,
    MIN(value) as min_value,
    MAX(value) as max_value,
    AVG(value) as avg_value,
    STDDEV(value) as stddev_value,
    COUNT(CASE WHEN value < 0 THEN 1 END) as negative_values,
    COUNT(CASE WHEN value = 0 THEN 1 END) as zero_values,
    COUNT(CASE WHEN value > 100 THEN 1 END) as high_values
FROM (
    SELECT 'otkazani_putnici' as column_name, otkazani_putnici as value FROM daily_reports
    UNION ALL
    SELECT 'naplaceni_putnici' as column_name, naplaceni_putnici as value FROM daily_reports
    UNION ALL
    SELECT 'pokupljeni_putnici' as column_name, pokupljeni_putnici as value FROM daily_reports
    UNION ALL
    SELECT 'dugovi_putnici' as column_name, dugovi_putnici as value FROM daily_reports
    UNION ALL
    SELECT 'mesecne_karte' as column_name, mesecne_karte as value FROM daily_reports
) passenger_data
GROUP BY column_name;

-- TEST 8: DETALJNA ANALIZA TIMESTAMP KOLONA
SELECT
    'Timestamp Columns Ultra Analysis' as analysis_type,
    'checkin_vreme' as column_name,
    COUNT(CASE WHEN checkin_vreme IS NULL THEN 1 END) as null_count,
    MIN(checkin_vreme) as earliest_checkin,
    MAX(checkin_vreme) as latest_checkin,
    MAX(checkin_vreme) - MIN(checkin_vreme) as checkin_time_range,
    COUNT(CASE WHEN checkin_vreme > CURRENT_TIMESTAMP THEN 1 END) as future_checkins,
    COUNT(CASE WHEN checkin_vreme < CURRENT_TIMESTAMP - INTERVAL '1 year' THEN 1 END) as old_checkins
FROM daily_reports
UNION ALL
SELECT
    'Timestamp Columns Ultra Analysis' as analysis_type,
    'created_at' as column_name,
    COUNT(CASE WHEN created_at IS NULL THEN 1 END) as null_count,
    MIN(created_at) as earliest_created,
    MAX(created_at) as latest_created,
    MAX(created_at) - MIN(created_at) as created_time_range,
    COUNT(CASE WHEN created_at > CURRENT_TIMESTAMP THEN 1 END) as future_creations,
    COUNT(CASE WHEN created_at < CURRENT_TIMESTAMP - INTERVAL '1 year' THEN 1 END) as old_creations
FROM daily_reports;

-- TEST 9: DETALJNA ANALIZA BOOLEAN KOLONE
SELECT
    'Boolean Column Ultra Analysis' as analysis_type,
    COUNT(*) as total_reports,
    COUNT(CASE WHEN automatski_generisan = true THEN 1 END) as auto_generated_true,
    COUNT(CASE WHEN automatski_generisan = false THEN 1 END) as auto_generated_false,
    COUNT(CASE WHEN automatski_generisan IS NULL THEN 1 END) as auto_generated_null,
    ROUND(COUNT(CASE WHEN automatski_generisan = true THEN 1 END)::numeric / COUNT(*) * 100, 2) as auto_generated_percentage,
    CASE
        WHEN COUNT(CASE WHEN automatski_generisan IS NULL THEN 1 END) = 0 THEN 'ALL_VALUES_SET'
        ELSE 'NULL_VALUES_EXIST'
    END as null_status,
    CASE
        WHEN COUNT(CASE WHEN automatski_generisan = true THEN 1 END) = COUNT(*) THEN 'ALL_AUTO_GENERATED'
        WHEN COUNT(CASE WHEN automatski_generisan = false THEN 1 END) = COUNT(*) THEN 'ALL_MANUAL'
        ELSE 'MIXED_GENERATION'
    END as generation_pattern
FROM daily_reports;

-- TEST 10: DETALJNA ANALIZA VOZAC_ID KOLONE (FOREIGN KEY)
SELECT
    'VOZAC_ID Column Ultra Analysis' as analysis_type,
    COUNT(DISTINCT vozac_id) as unique_driver_ids,
    COUNT(CASE WHEN vozac_id IS NULL THEN 1 END) as null_driver_ids,
    COUNT(*) as total_reports,
    COUNT(DISTINCT vozac_id) - COUNT(CASE WHEN vozac_id IS NULL THEN 1 END) as valid_driver_ids,
    CASE
        WHEN COUNT(CASE WHEN vozac_id IS NULL THEN 1 END) = 0 THEN 'ALL_HAVE_DRIVER_ID'
        ELSE 'SOME_MISSING_DRIVER_ID'
    END as completeness_status,
    STRING_AGG(DISTINCT vozac_id::text, ', ') as all_driver_ids
FROM daily_reports;

-- TEST 11: BIZNIS LOGIKA - PUTNIK COUNTS RELATIONSHIPS
SELECT
    'Business Logic - Passenger Relationships' as analysis_type,
    COUNT(*) as total_reports,
    COUNT(CASE WHEN pokupljeni_putnici >= naplaceni_putnici + otkazani_putnici THEN 1 END) as valid_passenger_logic,
    COUNT(CASE WHEN pokupljeni_putnici < naplaceni_putnici + otkazani_putnici THEN 1 END) as invalid_passenger_logic,
    ROUND(COUNT(CASE WHEN pokupljeni_putnici >= naplaceni_putnici + otkazani_putnici THEN 1 END)::numeric / COUNT(*) * 100, 2) as valid_percentage,
    CASE
        WHEN COUNT(CASE WHEN pokupljeni_putnici >= naplaceni_putnici + otkazani_putnici THEN 1 END) = COUNT(*) THEN 'ALL_VALID'
        ELSE 'LOGIC_VIOLATIONS'
    END as logic_status
FROM daily_reports;

-- TEST 12: BIZNIS LOGIKA - FINANSIJSKE VALIDACIJE
SELECT
    'Business Logic - Financial Validations' as analysis_type,
    COUNT(CASE WHEN ukupan_pazar >= 0 THEN 1 END) as valid_revenue,
    COUNT(CASE WHEN sitan_novac >= 0 THEN 1 END) as valid_cash,
    COUNT(CASE WHEN kilometraza >= 0 THEN 1 END) as valid_distance,
    COUNT(CASE WHEN ukupan_pazar < 0 THEN 1 END) as negative_revenue,
    COUNT(CASE WHEN sitan_novac < 0 THEN 1 END) as negative_cash,
    COUNT(CASE WHEN kilometraza < 0 THEN 1 END) as negative_distance,
    CASE
        WHEN COUNT(CASE WHEN ukupan_pazar < 0 THEN 1 END) = 0
             AND COUNT(CASE WHEN sitan_novac < 0 THEN 1 END) = 0
             AND COUNT(CASE WHEN kilometraza < 0 THEN 1 END) = 0 THEN 'ALL_FINANCIAL_VALID'
        ELSE 'FINANCIAL_VIOLATIONS'
    END as financial_status
FROM daily_reports;

-- TEST 13: BIZNIS LOGIKA - VREMENSKE RELACIJE
SELECT
    'Business Logic - Temporal Relationships' as analysis_type,
    COUNT(CASE WHEN datum <= CURRENT_DATE THEN 1 END) as valid_dates,
    COUNT(CASE WHEN checkin_vreme >= datum::timestamp THEN 1 END) as valid_checkin_times,
    COUNT(CASE WHEN created_at >= checkin_vreme THEN 1 END) as valid_creation_times,
    COUNT(CASE WHEN datum > CURRENT_DATE THEN 1 END) as future_dates,
    COUNT(CASE WHEN checkin_vreme < datum::timestamp THEN 1 END) as early_checkins,
    COUNT(CASE WHEN created_at < checkin_vreme THEN 1 END) as creation_before_checkin,
    CASE
        WHEN COUNT(CASE WHEN datum > CURRENT_DATE THEN 1 END) = 0
             AND COUNT(CASE WHEN checkin_vreme < datum::timestamp THEN 1 END) = 0
             AND COUNT(CASE WHEN created_at < checkin_vreme THEN 1 END) = 0 THEN 'ALL_TEMPORAL_VALID'
        ELSE 'TEMPORAL_VIOLATIONS'
    END as temporal_status
FROM daily_reports;

-- TEST 14: PERFORMANCE ANALIZA - INDEX STATISTICS
SELECT
    schemaname,
    tablename,
    attname as column_name,
    n_distinct,
    correlation,
    CASE
        WHEN n_distinct > 0.5 THEN 'HIGH_CARDINALITY'
        WHEN n_distinct > 0.1 THEN 'MEDIUM_CARDINALITY'
        ELSE 'LOW_CARDINALITY'
    END as cardinality_level,
    CASE
        WHEN correlation > 0.7 THEN 'WELL_CORRELATED'
        WHEN correlation > 0.3 THEN 'MODERATELY_CORRELATED'
        ELSE 'POORLY_CORRELATED'
    END as correlation_level
FROM pg_stats
WHERE tablename = 'daily_reports'
ORDER BY attname;

-- TEST 15: PERFORMANCE ANALIZA - QUERY PLANS
EXPLAIN (ANALYZE, VERBOSE, COSTS, BUFFERS, TIMING)
SELECT
    vozac,
    datum,
    ukupan_pazar,
    pokupljeni_putnici
FROM daily_reports
WHERE datum >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY datum DESC;

-- TEST 16: DATA QUALITY - COMPLETENESS ANALYSIS
SELECT
    'Data Quality - Completeness' as analysis_type,
    column_name,
    ROUND((COUNT(*) - COUNT(CASE WHEN value IS NULL THEN 1 END))::numeric / COUNT(*) * 100, 2) as completeness_percentage,
    COUNT(CASE WHEN value IS NULL THEN 1 END) as null_count,
    COUNT(*) as total_count,
    CASE
        WHEN (COUNT(*) - COUNT(CASE WHEN value IS NULL THEN 1 END))::numeric / COUNT(*) = 1 THEN '100%_COMPLETE'
        WHEN (COUNT(*) - COUNT(CASE WHEN value IS NULL THEN 1 END))::numeric / COUNT(*) >= 0.95 THEN 'HIGHLY_COMPLETE'
        WHEN (COUNT(*) - COUNT(CASE WHEN value IS NULL THEN 1 END))::numeric / COUNT(*) >= 0.80 THEN 'MODERATELY_COMPLETE'
        ELSE 'INCOMPLETE'
    END as completeness_level
FROM (
    SELECT 'id' as column_name, id::text as value FROM daily_reports
    UNION ALL SELECT 'vozac', vozac FROM daily_reports
    UNION ALL SELECT 'datum', datum::text FROM daily_reports
    UNION ALL SELECT 'ukupan_pazar', ukupan_pazar::text FROM daily_reports
    UNION ALL SELECT 'sitan_novac', sitan_novac::text FROM daily_reports
    UNION ALL SELECT 'checkin_vreme', checkin_vreme::text FROM daily_reports
    UNION ALL SELECT 'otkazani_putnici', otkazani_putnici::text FROM daily_reports
    UNION ALL SELECT 'naplaceni_putnici', naplaceni_putnici::text FROM daily_reports
    UNION ALL SELECT 'pokupljeni_putnici', pokupljeni_putnici::text FROM daily_reports
    UNION ALL SELECT 'dugovi_putnici', dugovi_putnici::text FROM daily_reports
    UNION ALL SELECT 'mesecne_karte', mesecne_karte::text FROM daily_reports
    UNION ALL SELECT 'kilometraza', kilometraza::text FROM daily_reports
    UNION ALL SELECT 'automatski_generisan', automatski_generisan::text FROM daily_reports
    UNION ALL SELECT 'created_at', created_at::text FROM daily_reports
    UNION ALL SELECT 'vozac_id', vozac_id::text FROM daily_reports
) completeness_data
GROUP BY column_name
ORDER BY completeness_percentage DESC;

-- TEST 17: DATA QUALITY - ACCURACY ANALYSIS
SELECT
    'Data Quality - Accuracy' as analysis_type,
    'UUID_Format' as check_type,
    COUNT(CASE WHEN LENGTH(id::text) = 36 AND id::text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN 1 END) as valid_uuids,
    COUNT(*) as total_ids,
    ROUND(COUNT(CASE WHEN LENGTH(id::text) = 36 AND id::text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN 1 END)::numeric / COUNT(*) * 100, 2) as accuracy_percentage
FROM daily_reports
UNION ALL
SELECT
    'Data Quality - Accuracy' as analysis_type,
    'Numeric_Positive' as check_type,
    COUNT(CASE WHEN ukupan_pazar >= 0 AND sitan_novac >= 0 AND kilometraza >= 0 THEN 1 END) as valid_financial,
    COUNT(*) as total_records,
    ROUND(COUNT(CASE WHEN ukupan_pazar >= 0 AND sitan_novac >= 0 AND kilometraza >= 0 THEN 1 END)::numeric / COUNT(*) * 100, 2) as accuracy_percentage
FROM daily_reports
UNION ALL
SELECT
    'Data Quality - Accuracy' as analysis_type,
    'Integer_Positive' as check_type,
    COUNT(CASE WHEN otkazani_putnici >= 0 AND naplaceni_putnici >= 0 AND pokupljeni_putnici >= 0 AND dugovi_putnici >= 0 AND mesecne_karte >= 0 THEN 1 END) as valid_counts,
    COUNT(*) as total_records,
    ROUND(COUNT(CASE WHEN otkazani_putnici >= 0 AND naplaceni_putnici >= 0 AND pokupljeni_putnici >= 0 AND dugovi_putnici >= 0 AND mesecne_karte >= 0 THEN 1 END)::numeric / COUNT(*) * 100, 2) as accuracy_percentage
FROM daily_reports;

-- TEST 18: RELATIONSHIP VALIDATION - FOREIGN KEYS
SELECT
    'Relationship Validation' as analysis_type,
    'vozac_id_references' as relationship_type,
    COUNT(DISTINCT dr.vozac_id) as referenced_driver_ids,
    COUNT(DISTINCT v.id) as existing_driver_ids,
    COUNT(DISTINCT dr.vozac_id) - COUNT(DISTINCT CASE WHEN v.id IS NOT NULL THEN dr.vozac_id END) as orphaned_references,
    CASE
        WHEN COUNT(DISTINCT dr.vozac_id) - COUNT(DISTINCT CASE WHEN v.id IS NOT NULL THEN dr.vozac_id END) = 0 THEN 'ALL_REFERENCES_VALID'
        ELSE 'ORPHANED_REFERENCES_EXIST'
    END as fk_status
FROM daily_reports dr
LEFT JOIN vozaci v ON dr.vozac_id = v.id;

-- TEST 19: STATISTICAL ANALYSIS - COLUMN DISTRIBUTIONS
SELECT
    'Statistical Analysis - Distributions' as analysis_type,
    'vozac_distribution' as metric,
    vozac as value,
    COUNT(*) as frequency,
    ROUND(COUNT(*)::numeric / SUM(COUNT(*)) OVER () * 100, 2) as percentage
FROM daily_reports
GROUP BY vozac
ORDER BY frequency DESC;

-- TEST 20: COMPREHENSIVE SYSTEM HEALTH CHECK
SELECT
    'SYSTEM HEALTH CHECK' as check_type,
    (SELECT COUNT(*) FROM daily_reports) as total_reports,
    (SELECT COUNT(DISTINCT id) FROM daily_reports) as unique_reports,
    (SELECT COUNT(*) FROM daily_reports WHERE id IS NOT NULL AND vozac IS NOT NULL AND datum IS NOT NULL) as complete_basic_info,
    (SELECT COUNT(*) FROM daily_reports WHERE ukupan_pazar >= 0 AND sitan_novac >= 0 AND kilometraza >= 0) as valid_financial_data,
    (SELECT COUNT(*) FROM daily_reports WHERE otkazani_putnici >= 0 AND naplaceni_putnici >= 0 AND pokupljeni_putnici >= 0) as valid_passenger_data,
    (SELECT COUNT(*) FROM daily_reports WHERE pokupljeni_putnici >= naplaceni_putnici + otkazani_putnici) as valid_business_logic,
    CASE
        WHEN (SELECT COUNT(*) FROM daily_reports) = (SELECT COUNT(DISTINCT id) FROM daily_reports)
             AND (SELECT COUNT(*) FROM daily_reports WHERE id IS NOT NULL AND vozac IS NOT NULL AND datum IS NOT NULL) = (SELECT COUNT(*) FROM daily_reports)
             AND (SELECT COUNT(*) FROM daily_reports WHERE ukupan_pazar >= 0 AND sitan_novac >= 0 AND kilometraza >= 0) = (SELECT COUNT(*) FROM daily_reports)
             AND (SELECT COUNT(*) FROM daily_reports WHERE pokupljeni_putnici >= naplaceni_putnici + otkazani_putnici) = (SELECT COUNT(*) FROM daily_reports)
        THEN 'SYSTEM_HEALTHY'
        ELSE 'SYSTEM_NEEDS_ATTENTION'
    END as overall_health_status
FROM daily_reports
LIMIT 1;
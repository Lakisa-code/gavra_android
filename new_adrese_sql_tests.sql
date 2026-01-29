-- =====================================================
-- NOVI SQL TESTOVI ZA adrese TABELU
-- Kreirano od strane GitHub Copilot - Januar 2026
-- =====================================================

-- TEST 1: Osnovne informacije o tabeli
SELECT
    'adrese' as table_name,
    COUNT(*) as total_addresses,
    COUNT(DISTINCT grad) as unique_cities,
    COUNT(DISTINCT ulica) as unique_streets,
    COUNT(CASE WHEN koordinate IS NOT NULL THEN 1 END) as with_coordinates
FROM adrese;

-- TEST 2: Struktura tabele
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default,
    CASE
        WHEN column_name = 'id' THEN 'PRIMARY KEY'
        WHEN column_name = 'naziv' THEN 'REQUIRED'
        ELSE 'OPTIONAL'
    END as constraint_type
FROM information_schema.columns
WHERE table_name = 'adrese'
ORDER BY ordinal_position;

-- TEST 3: Distribucija po gradovima
SELECT
    grad,
    COUNT(*) as broj_adresa,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) as procenat,
    COUNT(DISTINCT ulica) as jedinstvenih_ulica,
    COUNT(CASE WHEN broj IS NOT NULL THEN 1 END) as sa_brojem
FROM adrese
GROUP BY grad
ORDER BY COUNT(*) DESC;

-- TEST 4: Analiza kompletnosti adresa
SELECT
    'Address Completeness Analysis' as analysis_type,
    COUNT(*) as total_addresses,
    COUNT(CASE WHEN ulica IS NOT NULL AND broj IS NOT NULL THEN 1 END) as complete_addresses,
    COUNT(CASE WHEN ulica IS NOT NULL AND broj IS NULL THEN 1 END) as street_only,
    COUNT(CASE WHEN ulica IS NULL AND broj IS NULL THEN 1 END) as name_only,
    ROUND(100.0 * COUNT(CASE WHEN ulica IS NOT NULL AND broj IS NOT NULL THEN 1 END) / COUNT(*), 2) as completeness_percentage
FROM adrese;

-- TEST 5: Koordinate analiza
SELECT
    'Coordinates Analysis' as analysis_type,
    COUNT(*) as total_addresses,
    COUNT(CASE WHEN koordinate IS NOT NULL THEN 1 END) as with_coordinates,
    COUNT(CASE WHEN koordinate->>'lat' IS NOT NULL THEN 1 END) as with_latitude,
    COUNT(CASE WHEN koordinate->>'lng' IS NOT NULL THEN 1 END) as with_longitude,
    COUNT(CASE WHEN koordinate->>'source' IS NOT NULL THEN 1 END) as learned_coordinates,
    ROUND(AVG((koordinate->>'lat')::numeric), 6) as avg_latitude,
    ROUND(AVG((koordinate->>'lng')::numeric), 6) as avg_longitude
FROM adrese;

-- TEST 6: Najčešće ulice
SELECT
    ulica,
    grad,
    COUNT(*) as broj_adresa,
    STRING_AGG(naziv, ', ') as adrese
FROM adrese
WHERE ulica IS NOT NULL
GROUP BY ulica, grad
ORDER BY COUNT(*) DESC
LIMIT 10;

-- TEST 7: Adrese bez ulice/broja
SELECT
    naziv,
    grad,
    koordinate
FROM adrese
WHERE ulica IS NULL OR broj IS NULL
ORDER BY grad, naziv;

-- TEST 8: Geografski opseg
SELECT
    'Geographic Bounds' as bounds_type,
    MIN((koordinate->>'lat')::numeric) as min_lat,
    MAX((koordinate->>'lat')::numeric) as max_lat,
    MIN((koordinate->>'lng')::numeric) as min_lng,
    MAX((koordinate->>'lng')::numeric) as max_lng,
    ROUND(MAX((koordinate->>'lat')::numeric) - MIN((koordinate->>'lat')::numeric), 6) as lat_range,
    ROUND(MAX((koordinate->>'lng')::numeric) - MIN((koordinate->>'lng')::numeric), 6) as lng_range
FROM adrese
WHERE koordinate IS NOT NULL;

-- TEST 9: Duplikati provera
SELECT
    'Duplicate Check' as check_type,
    COUNT(*) as total_addresses,
    COUNT(DISTINCT (naziv, grad)) as unique_name_city,
    COUNT(DISTINCT (ulica, broj, grad)) as unique_street_number_city,
    (COUNT(*) - COUNT(DISTINCT (naziv, grad))) as name_city_duplicates,
    (COUNT(*) - COUNT(DISTINCT (ulica, broj, grad))) as street_duplicates
FROM adrese;

-- TEST 10: Analiza izvora koordinata
SELECT
    koordinate->>'source' as coordinate_source,
    COUNT(*) as count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) as percentage
FROM adrese
WHERE koordinate->>'source' IS NOT NULL
GROUP BY koordinate->>'source'
ORDER BY COUNT(*) DESC;

-- TEST 11: Vremenska analiza učenja koordinata
SELECT
    DATE_TRUNC('day', (koordinate->>'learned_at')::timestamp) as learned_date,
    COUNT(*) as addresses_learned,
    STRING_AGG(naziv, ', ') as addresses
FROM adrese
WHERE koordinate->>'learned_at' IS NOT NULL
GROUP BY DATE_TRUNC('day', (koordinate->>'learned_at')::timestamp)
ORDER BY learned_date DESC;

-- TEST 12: Provera integriteta podataka
SELECT
    'Data Integrity Check' as check_type,
    COUNT(*) as total_rows,
    COUNT(CASE WHEN id IS NULL THEN 1 END) as null_ids,
    COUNT(CASE WHEN naziv IS NULL OR naziv = '' THEN 1 END) as null_names,
    COUNT(CASE WHEN koordinate IS NULL THEN 1 END) as null_coordinates,
    COUNT(CASE WHEN grad IS NULL THEN 1 END) as null_cities,
    CASE
        WHEN COUNT(CASE WHEN naziv IS NULL OR naziv = '' THEN 1 END) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END as name_integrity,
    CASE
        WHEN COUNT(CASE WHEN koordinate IS NULL THEN 1 END) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END as coordinate_integrity
FROM adrese;

-- TEST 13: Pretraga po nazivu
SELECT
    naziv,
    grad,
    ulica,
    broj,
    koordinate
FROM adrese
WHERE naziv ILIKE '%škola%' OR naziv ILIKE '%bolnica%' OR naziv ILIKE '%pošta%'
ORDER BY grad, naziv;

-- TEST 14: Adrese sa posebnim karakteristikama
SELECT
    'Special Addresses' as category,
    COUNT(CASE WHEN naziv ILIKE '%škola%' THEN 1 END) as schools,
    COUNT(CASE WHEN naziv ILIKE '%bolnica%' THEN 1 END) as hospitals,
    COUNT(CASE WHEN naziv ILIKE '%pošta%' THEN 1 END) as post_offices,
    COUNT(CASE WHEN naziv ILIKE '%prodavnica%' OR naziv ILIKE '%market%' THEN 1 END) as stores,
    COUNT(CASE WHEN naziv ILIKE '%restoran%' OR naziv ILIKE '%kafe%' THEN 1 END) as restaurants
FROM adrese;

-- TEST 15: Performance test - brzo pretraživanje
EXPLAIN (ANALYZE, VERBOSE, COSTS, BUFFERS, TIMING)
SELECT
    naziv,
    grad,
    ulica,
    broj
FROM adrese
WHERE grad = 'Bela Crkva'
ORDER BY naziv
LIMIT 20;

-- TEST 16: Koordinate validacija
SELECT
    'Coordinate Validation' as validation_type,
    COUNT(*) as total_coordinates,
    COUNT(CASE
        WHEN (koordinate->>'lat')::numeric BETWEEN -90 AND 90
             AND (koordinate->>'lng')::numeric BETWEEN -180 AND 180
        THEN 1 END) as valid_coordinates,
    COUNT(CASE
        WHEN (koordinate->>'lat')::numeric NOT BETWEEN -90 AND 90
             OR (koordinate->>'lng')::numeric NOT BETWEEN -180 AND 180
        THEN 1 END) as invalid_coordinates,
    ROUND(100.0 * COUNT(CASE
        WHEN (koordinate->>'lat')::numeric BETWEEN -90 AND 90
             AND (koordinate->>'lng')::numeric BETWEEN -180 AND 180
        THEN 1 END) / COUNT(*), 2) as validity_percentage
FROM adrese
WHERE koordinate IS NOT NULL;

-- TEST 17: Analiza dužine naziva
SELECT
    'Name Length Analysis' as analysis_type,
    AVG(LENGTH(naziv)) as avg_name_length,
    MIN(LENGTH(naziv)) as min_name_length,
    MAX(LENGTH(naziv)) as max_name_length,
    COUNT(CASE WHEN LENGTH(naziv) < 5 THEN 1 END) as short_names,
    COUNT(CASE WHEN LENGTH(naziv) BETWEEN 5 AND 20 THEN 1 END) as medium_names,
    COUNT(CASE WHEN LENGTH(naziv) > 20 THEN 1 END) as long_names
FROM adrese;

-- TEST 18: Backup i recovery provera
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
WHERE tablename = 'adrese';

-- TEST 19: Trendovi dodavanja adresa
WITH address_trends AS (
    SELECT
        DATE_TRUNC('week', (koordinate->>'learned_at')::timestamp) as week,
        COUNT(*) as addresses_added
    FROM adrese
    WHERE koordinate->>'learned_at' IS NOT NULL
    GROUP BY DATE_TRUNC('week', (koordinate->>'learned_at')::timestamp)
    ORDER BY week
),
trends_calc AS (
    SELECT
        week,
        addresses_added,
        LAG(addresses_added) OVER (ORDER BY week) as prev_week,
        ROUND(
            100.0 * (addresses_added - LAG(addresses_added) OVER (ORDER BY week)) /
            NULLIF(LAG(addresses_added) OVER (ORDER BY week), 0), 2
        ) as week_over_week_change
    FROM address_trends
)
SELECT
    week::date,
    addresses_added,
    COALESCE(week_over_week_change, 0) || '%' as wow_change
FROM trends_calc
ORDER BY week DESC;

-- TEST 20: Završni status provera
SELECT
    CASE WHEN COUNT(*) > 0 THEN '✅ TABLE EXISTS' ELSE '❌ TABLE MISSING' END as table_status,
    CASE WHEN SUM(CASE WHEN naziv IS NOT NULL THEN 1 ELSE 0 END) = COUNT(*) THEN '✅ NAMES COMPLETE' ELSE '❌ MISSING NAMES' END as name_completeness,
    CASE WHEN SUM(CASE WHEN koordinate IS NOT NULL THEN 1 ELSE 0 END) = COUNT(*) THEN '✅ COORDINATES COMPLETE' ELSE '❌ MISSING COORDINATES' END as coordinate_completeness,
    CASE WHEN COUNT(DISTINCT grad) >= 3 THEN '✅ GOOD COVERAGE' ELSE '❌ POOR COVERAGE' END as geographic_coverage,
    CASE WHEN AVG(LENGTH(naziv)) BETWEEN 5 AND 25 THEN '✅ GOOD NAME LENGTH' ELSE '❌ NAME LENGTH ISSUES' END as name_quality
FROM adrese;
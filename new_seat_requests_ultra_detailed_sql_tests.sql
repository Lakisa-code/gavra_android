-- ULTRA-DETAJNI SQL TESTOVI ZA seat_requests TABELU
-- Kreiran od strane GitHub Copilot - Januar 2026
-- 20 ultra-detaljnih upita za validaciju svih aspekata

-- =====================================================
-- 1. SCHEMA INTEGRITY TESTS
-- =====================================================

-- 1.1 Provera postojanja tabele
SELECT
    schemaname,
    tablename,
    tableowner
FROM pg_tables
WHERE tablename = 'seat_requests';

-- 1.2 Detaljna analiza kolona
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default,
    character_maximum_length,
    numeric_precision,
    numeric_scale
FROM information_schema.columns
WHERE table_name = 'seat_requests'
ORDER BY ordinal_position;

-- 1.3 Provera constraints
SELECT
    tc.constraint_name,
    tc.constraint_type,
    tc.table_name,
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
WHERE tc.table_name = 'seat_requests';

-- =====================================================
-- 2. DATA TYPE VALIDATION TESTS
-- =====================================================

-- 2.1 UUID format validation
SELECT
    id,
    CASE
        WHEN id::text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN 'VALID UUID'
        ELSE 'INVALID UUID'
    END as uuid_validation
FROM seat_requests;

-- 2.2 Date format validation
SELECT
    datum_putovanja,
    CASE
        WHEN datum_putovanja IS NOT NULL THEN 'VALID DATE'
        ELSE 'NULL DATE'
    END as date_validation
FROM seat_requests;

-- 2.3 Integer validation for seat numbers
SELECT
    sediste_broj,
    CASE
        WHEN sediste_broj > 0 AND sediste_broj <= 50 THEN 'VALID SEAT'
        WHEN sediste_broj IS NULL THEN 'NULL SEAT'
        ELSE 'INVALID SEAT'
    END as seat_validation
FROM seat_requests;

-- =====================================================
-- 3. CONSTRAINT VALIDATION TESTS
-- =====================================================

-- 3.1 NOT NULL constraint validation
SELECT
    COUNT(*) as total_records,
    COUNT(id) as non_null_ids,
    COUNT(putnik_id) as non_null_putnik_ids,
    COUNT(vozac_id) as non_null_vozac_ids,
    COUNT(datum_putovanja) as non_null_dates,
    COUNT(sediste_broj) as non_null_seats,
    COUNT(status) as non_null_statuses
FROM seat_requests;

-- 3.2 DEFAULT value validation
SELECT
    COUNT(*) as total_records,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as default_status_count,
    COUNT(created_at) as created_at_count,
    COUNT(updated_at) as updated_at_count
FROM seat_requests;

-- =====================================================
-- 4. BUSINESS LOGIC TESTS
-- =====================================================

-- 4.1 Seat number range validation
SELECT
    MIN(sediste_broj) as min_seat,
    MAX(sediste_broj) as max_seat,
    AVG(sediste_broj) as avg_seat,
    COUNT(DISTINCT sediste_broj) as unique_seats
FROM seat_requests;

-- 4.2 Status distribution
SELECT
    status,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM seat_requests
GROUP BY status;

-- 4.3 Date range analysis
SELECT
    MIN(datum_putovanja) as earliest_date,
    MAX(datum_putovanja) as latest_date,
    COUNT(DISTINCT datum_putovanja) as unique_dates,
    COUNT(CASE WHEN datum_putovanja >= CURRENT_DATE THEN 1 END) as future_dates,
    COUNT(CASE WHEN datum_putovanja < CURRENT_DATE THEN 1 END) as past_dates
FROM seat_requests;

-- 4.4 Duplicate seat requests check
SELECT
    vozac_id,
    datum_putovanja,
    sediste_broj,
    COUNT(*) as duplicate_count
FROM seat_requests
GROUP BY vozac_id, datum_putovanja, sediste_broj
HAVING COUNT(*) > 1;

-- =====================================================
-- 5. RELATIONSHIP INTEGRITY TESTS
-- =====================================================

-- 5.1 Foreign key validation - putnik_id
SELECT sr.putnik_id, COUNT(*) as requests_count
FROM seat_requests sr
LEFT JOIN putnici p ON sr.putnik_id = p.id
WHERE p.id IS NULL
GROUP BY sr.putnik_id;

-- 5.2 Foreign key validation - vozac_id
SELECT sr.vozac_id, COUNT(*) as requests_count
FROM seat_requests sr
LEFT JOIN vozaci v ON sr.vozac_id = v.id
WHERE v.id IS NULL
GROUP BY sr.vozac_id;

-- =====================================================
-- 6. PERFORMANCE ANALYSIS TESTS
-- =====================================================

-- 6.1 Index analysis
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'seat_requests';

-- 6.2 Table size analysis
SELECT
    schemaname,
    tablename,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes,
    n_live_tup as live_rows,
    n_dead_tup as dead_rows
FROM pg_stat_user_tables
WHERE tablename = 'seat_requests';

-- 6.3 Query performance test
EXPLAIN ANALYZE
SELECT * FROM seat_requests
WHERE vozac_id = 'some-uuid-here'
  AND datum_putovanja >= CURRENT_DATE
  AND status = 'pending';

-- =====================================================
-- 7. DATA QUALITY TESTS
-- =====================================================

-- 7.1 Completeness analysis
SELECT
    'id' as column_name, ROUND(COUNT(id) * 100.0 / COUNT(*), 2) as completeness_pct FROM seat_requests
UNION ALL
SELECT 'putnik_id', ROUND(COUNT(putnik_id) * 100.0 / COUNT(*), 2) FROM seat_requests
UNION ALL
SELECT 'vozac_id', ROUND(COUNT(vozac_id) * 100.0 / COUNT(*), 2) FROM seat_requests
UNION ALL
SELECT 'datum_putovanja', ROUND(COUNT(datum_putovanja) * 100.0 / COUNT(*), 2) FROM seat_requests
UNION ALL
SELECT 'sediste_broj', ROUND(COUNT(sediste_broj) * 100.0 / COUNT(*), 2) FROM seat_requests
UNION ALL
SELECT 'status', ROUND(COUNT(status) * 100.0 / COUNT(*), 2) FROM seat_requests
UNION ALL
SELECT 'created_at', ROUND(COUNT(created_at) * 100.0 / COUNT(*), 2) FROM seat_requests
UNION ALL
SELECT 'updated_at', ROUND(COUNT(updated_at) * 100.0 / COUNT(*), 2) FROM seat_requests;

-- 7.2 Data consistency checks
SELECT
    COUNT(CASE WHEN created_at > updated_at THEN 1 END) as invalid_timestamps,
    COUNT(CASE WHEN datum_putovanja < CURRENT_DATE - INTERVAL '1 year' THEN 1 END) as old_requests,
    COUNT(CASE WHEN sediste_broj < 1 OR sediste_broj > 50 THEN 1 END) as invalid_seats
FROM seat_requests;

-- =====================================================
-- 8. STATISTICAL ANALYSIS TESTS
-- =====================================================

-- 8.1 Distribution analysis
SELECT
    'putnik_id' as dimension,
    COUNT(DISTINCT putnik_id) as unique_count,
    COUNT(*) / COUNT(DISTINCT putnik_id) as avg_requests_per_putnik
FROM seat_requests
UNION ALL
SELECT
    'vozac_id',
    COUNT(DISTINCT vozac_id),
    COUNT(*) / COUNT(DISTINCT vozac_id)
FROM seat_requests
UNION ALL
SELECT
    'datum_putovanja',
    COUNT(DISTINCT datum_putovanja),
    COUNT(*) / COUNT(DISTINCT datum_putovanja)
FROM seat_requests;

-- 8.2 Temporal patterns
SELECT
    DATE_TRUNC('month', created_at) as month,
    COUNT(*) as requests_created,
    COUNT(DISTINCT putnik_id) as unique_putnici,
    COUNT(DISTINCT vozac_id) as unique_vozaci
FROM seat_requests
WHERE created_at >= CURRENT_DATE - INTERVAL '6 months'
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY month DESC;

-- =====================================================
-- 9. ANOMALY DETECTION TESTS
-- =====================================================

-- 9.1 Outlier detection for seat numbers
WITH stats AS (
    SELECT
        AVG(sediste_broj) as mean_seat,
        STDDEV(sediste_broj) as std_seat
    FROM seat_requests
)
SELECT
    sr.*,
    CASE
        WHEN ABS(sr.sediste_broj - s.mean_seat) > 3 * s.std_seat THEN 'OUTLIER'
        ELSE 'NORMAL'
    END as seat_anomaly
FROM seat_requests sr, stats s;

-- 9.2 Status transition anomalies
SELECT
    id,
    status,
    created_at,
    updated_at,
    CASE
        WHEN status = 'cancelled' AND created_at = updated_at THEN 'INSTANT_CANCEL'
        WHEN status = 'confirmed' AND updated_at - created_at < INTERVAL '1 minute' THEN 'QUICK_CONFIRM'
        ELSE 'NORMAL'
    END as transition_pattern
FROM seat_requests;

-- =====================================================
-- 10. COMPREHENSIVE VALIDATION TESTS
-- =====================================================

-- 10.1 Complete data validation report
SELECT
    'Total Records' as metric, COUNT(*)::text as value FROM seat_requests
UNION ALL
SELECT 'Valid UUIDs', COUNT(CASE WHEN id::text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN 1 END)::text FROM seat_requests
UNION ALL
SELECT 'Valid Dates', COUNT(datum_putovanja)::text FROM seat_requests
UNION ALL
SELECT 'Valid Seats', COUNT(CASE WHEN sediste_broj BETWEEN 1 AND 50 THEN 1 END)::text FROM seat_requests
UNION ALL
SELECT 'Valid Statuses', COUNT(CASE WHEN status IN ('pending', 'confirmed', 'cancelled') THEN 1 END)::text FROM seat_requests
UNION ALL
SELECT 'Valid References', (COUNT(*) - COUNT(CASE WHEN sr.putnik_id NOT IN (SELECT id FROM putnici) THEN 1 END) - COUNT(CASE WHEN sr.vozac_id NOT IN (SELECT id FROM vozaci) THEN 1 END))::text
FROM seat_requests sr;

-- 10.2 Business rule compliance report
SELECT
    'No Past Travel Dates' as rule,
    CASE WHEN COUNT(CASE WHEN datum_putovanja < CURRENT_DATE THEN 1 END) = 0 THEN 'PASS' ELSE 'FAIL' END as status
FROM seat_requests
UNION ALL
SELECT 'No Duplicate Seats',
    CASE WHEN COUNT(*) = COUNT(DISTINCT vozac_id || '-' || datum_putovanja || '-' || sediste_broj) THEN 'PASS' ELSE 'FAIL' END
FROM seat_requests
UNION ALL
SELECT 'Valid Status Transitions',
    CASE WHEN COUNT(CASE WHEN status NOT IN ('pending', 'confirmed', 'cancelled') THEN 1 END) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM seat_requests
UNION ALL
SELECT 'Timestamps Logical',
    CASE WHEN COUNT(CASE WHEN created_at > updated_at THEN 1 END) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM seat_requests;
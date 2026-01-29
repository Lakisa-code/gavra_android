-- =====================================================
-- NOVI SQL TESTOVI ZA admin_audit_logs TABELU
-- Kreirano od strane GitHub Copilot - Januar 2026
-- =====================================================

-- TEST 1: Osnovne informacije o tabeli
SELECT
    'admin_audit_logs' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT admin_name) as unique_admins,
    COUNT(DISTINCT action_type) as unique_actions
FROM admin_audit_logs;

-- TEST 2: Struktura tabele
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default,
    CASE
        WHEN column_name = 'id' THEN 'PRIMARY KEY'
        WHEN column_name IN ('admin_name', 'action_type') THEN 'REQUIRED'
        ELSE 'OPTIONAL'
    END as constraint_type
FROM information_schema.columns
WHERE table_name = 'admin_audit_logs'
ORDER BY ordinal_position;

-- TEST 3: Vremenski pregled aktivnosti
SELECT
    DATE_TRUNC('day', created_at) as activity_date,
    COUNT(*) as daily_actions,
    COUNT(DISTINCT admin_name) as active_admins,
    STRING_AGG(DISTINCT action_type, ', ') as action_types
FROM admin_audit_logs
GROUP BY DATE_TRUNC('day', created_at)
ORDER BY activity_date DESC;

-- TEST 4: Analiza tipova akcija sa procentima
WITH action_stats AS (
    SELECT
        action_type,
        COUNT(*) as action_count,
        ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) as percentage
    FROM admin_audit_logs
    GROUP BY action_type
)
SELECT
    action_type,
    action_count,
    percentage || '%' as percentage,
    CASE
        WHEN percentage >= 50 THEN 'HIGH'
        WHEN percentage >= 20 THEN 'MEDIUM'
        ELSE 'LOW'
    END as frequency_level
FROM action_stats
ORDER BY action_count DESC;

-- TEST 5: Admin aktivnost po danima
SELECT
    admin_name,
    DATE_TRUNC('day', created_at) as activity_date,
    COUNT(*) as actions_per_day,
    STRING_AGG(action_type, ', ') as actions
FROM admin_audit_logs
GROUP BY admin_name, DATE_TRUNC('day', created_at)
ORDER BY admin_name, activity_date DESC;

-- TEST 6: Najčešći vremenski slotovi
SELECT
    EXTRACT(HOUR FROM created_at) as hour_of_day,
    COUNT(*) as actions_in_hour,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) || '%' as percentage,
    STRING_AGG(DISTINCT action_type, ', ') as common_actions
FROM admin_audit_logs
GROUP BY EXTRACT(HOUR FROM created_at)
ORDER BY actions_in_hour DESC;

-- TEST 7: JSONB metadata analiza
SELECT
    COUNT(*) as total_with_metadata,
    COUNT(CASE WHEN metadata ? 'datum' THEN 1 END) as has_date,
    COUNT(CASE WHEN metadata ? 'vreme' THEN 1 END) as has_time,
    COUNT(CASE WHEN metadata ? 'new_value' THEN 1 END) as has_new_value,
    COUNT(CASE WHEN metadata ? 'old_value' THEN 1 END) as has_old_value,
    AVG((metadata->>'new_value')::numeric) as avg_new_value,
    AVG((metadata->>'old_value')::numeric) as avg_old_value
FROM admin_audit_logs
WHERE metadata IS NOT NULL;

-- TEST 8: Detalji promena kapaciteta
SELECT
    created_at,
    admin_name,
    details,
    metadata->>'datum' as change_date,
    metadata->>'vreme' as change_time,
    (metadata->>'new_value')::integer as new_capacity,
    (metadata->>'old_value')::integer as old_capacity,
    ((metadata->>'new_value')::integer - (metadata->>'old_value')::integer) as capacity_change
FROM admin_audit_logs
WHERE action_type = 'promena_kapaciteta'
ORDER BY created_at DESC
LIMIT 10;

-- TEST 9: Reset putnik kartica analiza
SELECT
    created_at,
    admin_name,
    details,
    metadata
FROM admin_audit_logs
WHERE action_type = 'reset_putnik_card'
ORDER BY created_at DESC;

-- TEST 10: Status promene
SELECT
    created_at,
    admin_name,
    details,
    metadata
FROM admin_audit_logs
WHERE action_type = 'change_status'
ORDER BY created_at DESC;

-- TEST 11: Brisanje putnika
SELECT
    created_at,
    admin_name,
    details,
    metadata
FROM admin_audit_logs
WHERE action_type = 'delete_passenger'
ORDER BY created_at DESC;

-- TEST 12: Provera integriteta podataka
SELECT
    'Data Integrity Check' as check_type,
    COUNT(*) as total_rows,
    COUNT(CASE WHEN id IS NULL THEN 1 END) as null_ids,
    COUNT(CASE WHEN admin_name IS NULL OR admin_name = '' THEN 1 END) as null_admin_names,
    COUNT(CASE WHEN action_type IS NULL OR action_type = '' THEN 1 END) as null_action_types,
    COUNT(CASE WHEN created_at IS NULL THEN 1 END) as null_timestamps,
    CASE
        WHEN COUNT(CASE WHEN admin_name IS NULL OR admin_name = '' THEN 1 END) = 0
             AND COUNT(CASE WHEN action_type IS NULL OR action_type = '' THEN 1 END) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END as integrity_status
FROM admin_audit_logs;

-- TEST 13: Duplikati provera
SELECT
    'Duplicate Check' as check_type,
    COUNT(*) as total_logs,
    COUNT(DISTINCT (admin_name, action_type, created_at::date, details)) as unique_logs,
    (COUNT(*) - COUNT(DISTINCT (admin_name, action_type, created_at::date, details))) as potential_duplicates
FROM admin_audit_logs;

-- TEST 14: Performance analiza
EXPLAIN (ANALYZE, VERBOSE, COSTS, BUFFERS, TIMING)
SELECT
    admin_name,
    action_type,
    COUNT(*) as action_count
FROM admin_audit_logs
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY admin_name, action_type
ORDER BY action_count DESC;

-- TEST 15: Trendovi aktivnosti
WITH daily_stats AS (
    SELECT
        DATE_TRUNC('day', created_at) as day,
        COUNT(*) as daily_count
    FROM admin_audit_logs
    GROUP BY DATE_TRUNC('day', created_at)
    ORDER BY day
),
trends AS (
    SELECT
        day,
        daily_count,
        LAG(daily_count) OVER (ORDER BY day) as prev_day_count,
        ROUND(
            100.0 * (daily_count - LAG(daily_count) OVER (ORDER BY day)) /
            NULLIF(LAG(daily_count) OVER (ORDER BY day), 0), 2
        ) as day_over_day_change
    FROM daily_stats
)
SELECT
    day::date,
    daily_count,
    COALESCE(day_over_day_change, 0) || '%' as day_change
FROM trends
ORDER BY day DESC;

-- TEST 16: Najduži period bez aktivnosti
WITH activity_days AS (
    SELECT DISTINCT DATE_TRUNC('day', created_at) as activity_day
    FROM admin_audit_logs
    ORDER BY activity_day
),
gaps AS (
    SELECT
        activity_day,
        LEAD(activity_day) OVER (ORDER BY activity_day) as next_activity_day,
        LEAD(activity_day) OVER (ORDER BY activity_day) - activity_day as gap_days
    FROM activity_days
)
SELECT
    activity_day::date as last_activity,
    next_activity_day::date as next_activity,
    gap_days as days_without_activity
FROM gaps
WHERE gap_days IS NOT NULL
ORDER BY gap_days DESC
LIMIT 5;

-- TEST 17: Kompletan izveštaj
SELECT
    'FINAL REPORT' as report_type,
    (SELECT COUNT(*) FROM admin_audit_logs) as total_logs,
    (SELECT COUNT(DISTINCT admin_name) FROM admin_audit_logs) as total_admins,
    (SELECT COUNT(DISTINCT action_type) FROM admin_audit_logs) as total_action_types,
    (SELECT MIN(created_at) FROM admin_audit_logs) as first_log,
    (SELECT MAX(created_at) FROM admin_audit_logs) as last_log,
    (SELECT EXTRACT(EPOCH FROM (MAX(created_at) - MIN(created_at)))/86400 FROM admin_audit_logs) as active_days,
    (SELECT ROUND(AVG(daily_count), 2) FROM (
        SELECT DATE_TRUNC('day', created_at) as day, COUNT(*) as daily_count
        FROM admin_audit_logs
        GROUP BY DATE_TRUNC('day', created_at)
    ) daily) as avg_daily_activity;

-- TEST 18: Preporuke za optimizaciju
SELECT
    'Optimization Recommendations' as recommendation_type,
    CASE
        WHEN (SELECT COUNT(*) FROM admin_audit_logs) > 1000 THEN 'Consider partitioning by month'
        ELSE 'Table size is manageable'
    END as partitioning,
    CASE
        WHEN (SELECT COUNT(DISTINCT admin_name) FROM admin_audit_logs) > 10 THEN 'Consider admin_name index'
        ELSE 'Current admin count is low'
    END as indexing,
    CASE
        WHEN (SELECT AVG(daily_count) FROM (
            SELECT DATE_TRUNC('day', created_at) as day, COUNT(*) as daily_count
            FROM admin_audit_logs
            GROUP BY DATE_TRUNC('day', created_at)
        ) daily) > 50 THEN 'High activity - monitor performance'
        ELSE 'Activity level is normal'
    END as monitoring;

-- TEST 19: Backup i recovery test
SELECT
    'Backup & Recovery Check' as check_type,
    schemaname,
    tablename,
    tableowner,
    tablespace,
    hasindexes,
    hasrules,
    hastriggers,
    rowsecurity
FROM pg_tables
WHERE tablename = 'admin_audit_logs';

-- TEST 20: Završni status
SELECT
    CASE WHEN COUNT(*) > 0 THEN '✅ TABLE EXISTS' ELSE '❌ TABLE MISSING' END as table_status,
    CASE WHEN SUM(CASE WHEN admin_name IS NOT NULL THEN 1 ELSE 0 END) = COUNT(*) THEN '✅ DATA INTEGRITY OK' ELSE '❌ DATA INTEGRITY ISSUES' END as data_integrity,
    CASE WHEN COUNT(DISTINCT action_type) >= 4 THEN '✅ ACTION TYPES COMPLETE' ELSE '❌ MISSING ACTION TYPES' END as action_completeness,
    CASE WHEN EXTRACT(EPOCH FROM (MAX(created_at) - MIN(created_at)))/86400 >= 7 THEN '✅ SUFFICIENT HISTORY' ELSE '❌ INSUFFICIENT HISTORY' END as history_coverage
FROM admin_audit_logs;
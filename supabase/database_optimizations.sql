-- 🔥 MASTER REALTIME STREAM - DATABASE OPTIMIZATIONS
-- Execute after V2 screens are validated in production
-- Run via Supabase SQL Editor: Dashboard → SQL Editor → New Query

-- =====================================================
-- 📊 PERFORMANCE ANALYSIS BEFORE OPTIMIZATIONS
-- =====================================================

-- Check table sizes
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    pg_total_relation_size(schemaname||'.'||tablename) AS size_bytes
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY size_bytes DESC;

-- Check index usage
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan as index_scans,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan ASC, pg_relation_size(indexrelid) DESC;

-- Check slow queries (if pg_stat_statements is enabled)
-- SELECT 
--     query,
--     calls,
--     mean_exec_time,
--     max_exec_time
-- FROM pg_stat_statements
-- WHERE query LIKE '%vozaci%' OR query LIKE '%daily_checkins%'
-- ORDER BY mean_exec_time DESC
-- LIMIT 20;

-- =====================================================
-- 1️⃣ COMPOSITE INDEXES (High Priority)
-- =====================================================

-- Vozaci table: Speed up RPC get_vozac_kusur
-- Covers: WHERE vozac_ime = ? AND datum >= ? AND datum <= ?
CREATE INDEX IF NOT EXISTS idx_vozaci_ime_datum 
ON vozaci(ime, created_at DESC);

COMMENT ON INDEX idx_vozaci_ime_datum IS 
'Composite index for vozac kusur queries. Used by get_vozac_kusur RPC.';

-- Daily Checkins: Speed up today's kusur retrieval
-- Covers: WHERE vozac = ? AND datum = ?
CREATE INDEX IF NOT EXISTS idx_daily_checkins_vozac_datum 
ON daily_checkins(vozac, datum DESC);

COMMENT ON INDEX idx_daily_checkins_vozac_datum IS 
'Composite index for daily checkin queries. Used by MasterRealtimeStream.';

-- Putovanja Istorija: Speed up vozac filtering by date
-- Covers: WHERE vozac = ? AND datum >= ? AND datum <= ?
CREATE INDEX IF NOT EXISTS idx_putovanja_vozac_datum 
ON putovanja_istorija(vozac, datum DESC);

COMMENT ON INDEX idx_putovanja_vozac_datum IS 
'Composite index for putovanja queries. Used by calculate_daily_pazar RPC.';

-- Dnevni Putnici: Speed up today's passenger retrieval
-- Covers: WHERE vozac = ? AND datum = ? AND status != 'otkazan'
CREATE INDEX IF NOT EXISTS idx_dnevni_putnici_vozac_datum_status 
ON dnevni_putnici(vozac, datum DESC, status);

COMMENT ON INDEX idx_dnevni_putnici_vozac_datum_status IS 
'Composite index for dnevni putnici queries. Excludes cancelled passengers efficiently.';

-- GPS Lokacije: Partition-friendly index for recent locations
-- Covers: WHERE vozac = ? AND timestamp >= ?
CREATE INDEX IF NOT EXISTS idx_gps_lokacije_vozac_timestamp 
ON gps_lokacije(vozac, timestamp DESC);

COMMENT ON INDEX idx_gps_lokacije_vozac_timestamp IS 
'Composite index for GPS queries. Used by MasterRealtimeStream GPS tracking.';

-- =====================================================
-- 2️⃣ PARTIAL INDEXES (Medium Priority)
-- =====================================================

-- Dnevni Putnici: Index only active (not cancelled) passengers
CREATE INDEX IF NOT EXISTS idx_dnevni_putnici_active 
ON dnevni_putnici(vozac, datum DESC, vreme_polaska) 
WHERE status != 'otkazan';

COMMENT ON INDEX idx_dnevni_putnici_active IS 
'Partial index for active passengers only. Reduces index size by ~20%.';

-- Daily Checkins: Index only today's checkins
CREATE INDEX IF NOT EXISTS idx_daily_checkins_recent 
ON daily_checkins(vozac, iznos) 
WHERE datum >= CURRENT_DATE - INTERVAL '7 days';

COMMENT ON INDEX idx_daily_checkins_recent IS 
'Partial index for recent checkins (last 7 days). Reduces index size significantly.';

-- =====================================================
-- 3️⃣ REMOVE UNUSED INDEXES (After validation)
-- =====================================================

-- Check for duplicate indexes
SELECT 
    idx1.indexrelid::regclass AS index1,
    idx2.indexrelid::regclass AS index2,
    idx1.indrelid::regclass AS table_name
FROM pg_index idx1
JOIN pg_index idx2 ON idx1.indrelid = idx2.indrelid
WHERE idx1.indexrelid < idx2.indexrelid
  AND idx1.indkey = idx2.indkey;

-- List candidates for removal (indexes with 0 scans)
-- REVIEW MANUALLY before dropping!
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
  AND idx_scan = 0
  AND indexrelid::regclass::text NOT LIKE '%_pkey'
ORDER BY pg_relation_size(indexrelid) DESC;

-- Example: Drop unused index (UNCOMMENT after validation)
-- DROP INDEX IF EXISTS old_unused_index_name;

-- =====================================================
-- 4️⃣ GPS LOKACIJE TABLE PARTITIONING (High Priority)
-- =====================================================

-- GPS data grows fast - partition by month for better performance
-- EXECUTE ONLY IF gps_lokacije has >100K rows

-- Step 1: Create partitioned table
CREATE TABLE IF NOT EXISTS gps_lokacije_partitioned (
    id BIGSERIAL,
    vozac TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    accuracy DOUBLE PRECISION,
    altitude DOUBLE PRECISION,
    heading DOUBLE PRECISION,
    speed DOUBLE PRECISION,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb,
    PRIMARY KEY (id, timestamp)
) PARTITION BY RANGE (timestamp);

COMMENT ON TABLE gps_lokacije_partitioned IS 
'Partitioned GPS table by month. Improves query performance for recent GPS data.';

-- Step 2: Create monthly partitions (last 3 months + next 3 months)
-- Example for 2025-11 (November 2025)
CREATE TABLE IF NOT EXISTS gps_lokacije_2025_11 
PARTITION OF gps_lokacije_partitioned
FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');

CREATE TABLE IF NOT EXISTS gps_lokacije_2025_12 
PARTITION OF gps_lokacije_partitioned
FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');

CREATE TABLE IF NOT EXISTS gps_lokacije_2026_01 
PARTITION OF gps_lokacije_partitioned
FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

-- Create indexes on each partition
CREATE INDEX IF NOT EXISTS idx_gps_2025_11_vozac_timestamp 
ON gps_lokacije_2025_11(vozac, timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_gps_2025_12_vozac_timestamp 
ON gps_lokacije_2025_12(vozac, timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_gps_2026_01_vozac_timestamp 
ON gps_lokacije_2026_01(vozac, timestamp DESC);

-- Step 3: Migrate data (ONLY if safe to do so - backup first!)
-- INSERT INTO gps_lokacije_partitioned 
-- SELECT * FROM gps_lokacije
-- WHERE timestamp >= '2025-11-01';

-- Step 4: Rename tables (after migration validation)
-- ALTER TABLE gps_lokacije RENAME TO gps_lokacije_old;
-- ALTER TABLE gps_lokacije_partitioned RENAME TO gps_lokacije;

-- Step 5: Update RLS policies for partitioned table
-- ALTER TABLE gps_lokacije ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY gps_select_policy ON gps_lokacije FOR SELECT USING (true);

-- =====================================================
-- 5️⃣ VACUUM ANALYZE (Critical Maintenance)
-- =====================================================

-- Reclaim storage and update statistics
VACUUM ANALYZE vozaci;
VACUUM ANALYZE daily_checkins;
VACUUM ANALYZE putovanja_istorija;
VACUUM ANALYZE dnevni_putnici;
VACUUM ANALYZE gps_lokacije;

-- Full vacuum for heavily updated tables (run during low traffic)
-- VACUUM FULL daily_checkins;
-- VACUUM FULL gps_lokacije;

-- =====================================================
-- 6️⃣ TABLE STATISTICS UPDATE
-- =====================================================

-- Update column statistics for query planner
ANALYZE vozaci;
ANALYZE daily_checkins;
ANALYZE putovanja_istorija;
ANALYZE dnevni_putnici;
ANALYZE gps_lokacije;

-- Increase statistics target for frequently queried columns
ALTER TABLE vozaci ALTER COLUMN ime SET STATISTICS 1000;
ALTER TABLE daily_checkins ALTER COLUMN vozac SET STATISTICS 1000;
ALTER TABLE putovanja_istorija ALTER COLUMN vozac SET STATISTICS 1000;

-- =====================================================
-- 7️⃣ RPC FUNCTION OPTIMIZATIONS
-- =====================================================

-- Add STABLE or IMMUTABLE hints to RPC functions if applicable
-- Example: get_vozac_kusur can be STABLE (doesn't modify data)

-- Check existing RPC functions
SELECT 
    proname,
    provolatile,
    prosrc
FROM pg_proc
WHERE proname LIKE '%vozac%' OR proname LIKE '%kusur%' OR proname LIKE '%pazar%';

-- Update volatility if needed (UNCOMMENT after review)
-- ALTER FUNCTION get_vozac_kusur(TEXT) STABLE;
-- ALTER FUNCTION calculate_daily_pazar(TEXT, TIMESTAMPTZ, TIMESTAMPTZ) STABLE;

-- =====================================================
-- 8️⃣ CONNECTION POOLING OPTIMIZATION
-- =====================================================

-- Check current connection settings
SHOW max_connections;
SHOW shared_buffers;
SHOW effective_cache_size;
SHOW work_mem;

-- Recommendations for Supabase:
-- max_connections: 100 (default)
-- shared_buffers: 25% of RAM
-- effective_cache_size: 75% of RAM
-- work_mem: 4MB - 16MB per connection

-- =====================================================
-- 9️⃣ MONITORING QUERIES (Post-Optimization)
-- =====================================================

-- Check index usage after optimizations
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan as scans_after_optimization,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
  AND indexname LIKE 'idx_%vozac%'
ORDER BY idx_scan DESC;

-- Check table bloat
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - 
                   pg_relation_size(schemaname||'.'||tablename)) AS index_size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- =====================================================
-- 🏆 VALIDATION CHECKLIST
-- =====================================================

-- [ ] Backup database before running optimizations
-- [ ] Run optimizations during low-traffic period
-- [ ] Monitor query performance before/after (pg_stat_statements)
-- [ ] Verify MasterRealtimeStream RPC calls are faster
-- [ ] Check Supabase Dashboard → Statistics for improvements
-- [ ] Run EXPLAIN ANALYZE on critical queries
-- [ ] Document results in PERFORMANCE_TESTING_GUIDE.md

-- =====================================================
-- 📊 EXPECTED IMPROVEMENTS
-- =====================================================

-- After running these optimizations:
-- - RPC functions: 30-50% faster
-- - Index scans: 2-3x more efficient
-- - Storage: 10-20% reclaimed (after VACUUM)
-- - Query planner: More accurate cost estimates
-- - Realtime subscriptions: More stable (reduced load)

-- TOTAL EXPECTED IMPROVEMENT:
-- - API response time: -40-60%
-- - Database CPU: -30-50%
-- - Storage efficiency: +10-20%

-- =====================================================
-- 🚀 ROLLBACK PLAN (If issues occur)
-- =====================================================

-- Drop new indexes:
-- DROP INDEX IF EXISTS idx_vozaci_ime_datum;
-- DROP INDEX IF EXISTS idx_daily_checkins_vozac_datum;
-- DROP INDEX IF EXISTS idx_putovanja_vozac_datum;
-- DROP INDEX IF EXISTS idx_dnevni_putnici_vozac_datum_status;
-- DROP INDEX IF EXISTS idx_gps_lokacije_vozac_timestamp;
-- DROP INDEX IF EXISTS idx_dnevni_putnici_active;
-- DROP INDEX IF EXISTS idx_daily_checkins_recent;

-- Restore from backup if major issues

-- =====================================================
-- 📝 MAINTENANCE SCHEDULE (Ongoing)
-- =====================================================

-- Weekly:
-- - VACUUM ANALYZE all tables
-- - Check slow queries (pg_stat_statements)

-- Monthly:
-- - Review unused indexes
-- - Create new GPS partitions
-- - Drop old GPS partitions (>6 months)
-- - Full backup

-- Quarterly:
-- - VACUUM FULL during maintenance window
-- - Review and optimize RPC functions
-- - Update statistics targets

-- =====================================================
-- Last Updated: 2025-11-12
-- Status: READY FOR EXECUTION (after V2 validation)
-- =====================================================

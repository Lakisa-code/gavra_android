-- =====================================================
-- MIGRACIJA: Dodavanje indeksa za user_daily_changes tabelu
-- Datum: 2026-01-31
-- Svrha: Poboljšanje performansi upita
-- =====================================================

-- Indeks za brže pretrage po datumu (koristi se u getTodayStats i cleanupOldRecords)
CREATE INDEX IF NOT EXISTS idx_user_daily_changes_datum
ON user_daily_changes (datum);

-- Kompozitni indeks za optimizaciju upita po putniku i datumu
CREATE INDEX IF NOT EXISTS idx_user_daily_changes_putnik_datum
ON user_daily_changes (putnik_id, datum);

-- Provera da li su indeksi uspešno kreirani
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'user_daily_changes'
ORDER BY indexname;
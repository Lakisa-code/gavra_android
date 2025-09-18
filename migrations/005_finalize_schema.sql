-- 005_finalize_schema.sql
-- Final schema adjustments for mesecni_putnici and putovanja_istorija
-- Adds GIN indexes for jsonb/text[] columns and safely removes legacy polazak_* columns
-- Run on a staging/dev database first. Make a full DB export before running on production.

BEGIN;

-- 1) Create GIN index on polasci_po_danu (jsonb) for fast path queries
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'i' AND c.relname = 'idx_mesecni_putnici_polasci_po_danu_gin'
  ) THEN
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mesecni_putnici_polasci_po_danu_gin
      ON mesecni_putnici USING gin (polasci_po_danu);
  END IF;
END$$;

-- 2) Create GIN index on statistics jsonb
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'i' AND c.relname = 'idx_mesecni_putnici_statistics_gin'
  ) THEN
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mesecni_putnici_statistics_gin
      ON mesecni_putnici USING gin (statistics);
  END IF;
END$$;

-- 3) Create GIN index for radni_dani_arr (text[])
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'mesecni_putnici') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE c.relkind = 'i' AND c.relname = 'idx_mesecni_putnici_radni_dani_arr_gin'
    ) THEN
      CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mesecni_putnici_radni_dani_arr_gin
        ON mesecni_putnici USING gin (radni_dani_arr);
    END IF;
  END IF;
END$$;

-- 4) Optional: add expression index on lower(status) for faster status filtering
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'i' AND c.relname = 'idx_putovanja_istorija_status_lower'
  ) THEN
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_putovanja_istorija_status_lower
      ON putovanja_istorija (lower(status));
  END IF;
END$$;

-- 5) Safely drop legacy polazak_* columns from mesecni_putnici
-- 5) NOTE: legacy `polazak_bc_*` and `polazak_vs_*` columns are NOT dropped
-- per user request to avoid backups. To remove them later, uncomment and
-- run a carefully-reviewed ALTER TABLE DROP COLUMN IF EXISTS list.

-- 6) OPTIONAL: drop legacy radni_dani text column if radni_dani_arr is verified
-- Uncomment only after verification and backups
-- ALTER TABLE IF EXISTS mesecni_putnici DROP COLUMN IF EXISTS radni_dani;

COMMIT;

-- Verification queries (run after migration)
-- SELECT count(*) FROM mesecni_putnici WHERE polasci_po_danu IS NULL OR polasci_po_danu = '{}';
-- SELECT count(*) FROM mesecni_putnici WHERE array_length(radni_dani_arr,1) IS NULL;
-- SELECT * FROM mesecni_putnici LIMIT 5;

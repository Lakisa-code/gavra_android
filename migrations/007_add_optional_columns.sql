-- migrations/007_add_optional_columns.sql
-- Add optional columns used by app (idempotent, non-destructive)
-- Run after verification. Safe to run multiple times.

BEGIN;

-- Add polasci_po_danu jsonb for monthly passenger schedule
ALTER TABLE IF EXISTS mesecni_putnici
  ADD COLUMN IF NOT EXISTS polasci_po_danu jsonb DEFAULT '[]'::jsonb;

-- Add radni_dani_arr for easy day containment checks
ALTER TABLE IF EXISTS mesecni_putnici
  ADD COLUMN IF NOT EXISTS radni_dani_arr text[];

-- Add numeric price column for safe numeric operations
ALTER TABLE IF EXISTS mesecni_putnici
  ADD COLUMN IF NOT EXISTS cena_numeric numeric;

-- Add flexible statistics jsonb
ALTER TABLE IF EXISTS mesecni_putnici
  ADD COLUMN IF NOT EXISTS statistics jsonb DEFAULT '{}'::jsonb;

COMMIT;

-- Create indexes outside of explicit transaction where needed
-- Note: CREATE INDEX CONCURRENTLY cannot run inside a transaction block.

-- GIN index on polasci_po_danu for jsonb containment/search
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                 WHERE c.relname = 'idx_mesecni_putnici_polasci_gin') THEN
    EXECUTE 'CREATE INDEX CONCURRENTLY idx_mesecni_putnici_polasci_gin ON mesecni_putnici USING gin (polasci_po_danu)';
  END IF;
END$$;

-- GIN index on statistics jsonb
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                 WHERE c.relname = 'idx_mesecni_putnici_statistics_gin') THEN
    EXECUTE 'CREATE INDEX CONCURRENTLY idx_mesecni_putnici_statistics_gin ON mesecni_putnici USING gin (statistics)';
  END IF;
END$$;

-- GIN index for radni_dani_arr (text[]) to speed up containment checks
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                 WHERE c.relname = 'idx_mesecni_putnici_radni_dani_gin') THEN
    EXECUTE 'CREATE INDEX CONCURRENTLY idx_mesecni_putnici_radni_dani_gin ON mesecni_putnici USING gin (radni_dani_arr)';
  END IF;
END$$;

-- Post-run notes:
-- - Run this on a staging copy first if possible.
-- - Index creation is done CONCURRENTLY to avoid long table locks, but may still use IO and take time.
-- - Backfill of data (moving legacy polazak_* columns into polasci_po_danu or filling radni_dani_arr)
--   should be performed separately after verification queries show how many rows need migration.

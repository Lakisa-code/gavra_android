-- migrations/008_apply_optional_and_backfill.sql
-- Idempotent schema additions + safe backfill for `cena_numeric`
-- Paste this into Supabase SQL Editor and run. Review results before running index statements.

-- 1) Add missing columns (safe / idempotent)
ALTER TABLE public.mesecni_putnici
  ADD COLUMN IF NOT EXISTS polasci_po_danu jsonb,
  ADD COLUMN IF NOT EXISTS radni_dani_arr text[],
  ADD COLUMN IF NOT EXISTS cena_numeric numeric,
  ADD COLUMN IF NOT EXISTS statistics jsonb;

-- 2) Safe backfill for `cena_numeric` from `cena` (non-destructive)
-- This normalizes strings like "350", "350.00", "350,00", "350 RSD", "350.00 RSD" -> numeric 350.00
DO $$
BEGIN
  IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='mesecni_putnici' AND column_name='cena') THEN
    -- Update only rows where cena is present and cena_numeric is NULL
    UPDATE mesecni_putnici
    SET cena_numeric = (
      CASE
        WHEN trim(cena::text) = '' THEN NULL
        ELSE NULLIF(regexp_replace(replace(trim(cena::text), ',', '.'), '[^0-9\.]', '', 'g'), '')::numeric
      END
    )
    WHERE cena IS NOT NULL AND (cena_numeric IS NULL);
  END IF;
END$$;

-- 3) Helper checks and samples (read-only, useful to inspect results)
-- Total rows
SELECT 'rows_total' AS key, count(*)::text AS value FROM mesecni_putnici;

-- How many still have cena text but no numeric parsed
SELECT 'cena_text_but_no_numeric' AS key, count(*)::text AS value
FROM mesecni_putnici WHERE cena IS NOT NULL AND cena_numeric IS NULL;

-- How many parsed but mismatch text vs numeric (sanity check)
SELECT 'cena_mismatch' AS key, count(*)::text AS value
FROM mesecni_putnici
WHERE cena IS NOT NULL AND cena_numeric IS NOT NULL
  AND trim(regexp_replace(replace(trim(cena::text),',','.'),'[^0-9\.]','','g')) <> trim(cena_numeric::text);

-- Show examples of problematic rows (useful to inspect manually)
SELECT id, putnik_ime, cena, cena_numeric
FROM mesecni_putnici
WHERE cena IS NOT NULL AND cena_numeric IS NULL
LIMIT 50;

-- 4) Guidance / helper queries for polasci_po_danu / radni_dani_arr backfill
-- These fields are application-specific and may require custom mapping from legacy columns.
-- Run the following to list candidate legacy columns to map from:
SELECT column_name
FROM information_schema.columns
WHERE table_schema='public' AND table_name='mesecni_putnici'
  AND (column_name ILIKE 'polazak%' OR column_name ILIKE 'polasci%' OR column_name ILIKE 'radni%')
ORDER BY column_name;

-- Example manual backfill pattern (uncomment and adapt if you have a single legacy text column `polasci_text`):
-- UPDATE mesecni_putnici
-- SET polasci_po_danu = (
--   CASE WHEN polasci_text IS NULL OR trim(polasci_text) = '' THEN '[]'::jsonb
--        ELSE (regexp_split_to_array(polasci_text, E'\\s*[,;]\\s*'))::jsonb
--   END
-- )
-- WHERE polasci_po_danu IS NULL;

-- 5) Index creation — run these AFTER you verify backfill is correct.
-- IMPORTANT: `CREATE INDEX CONCURRENTLY` cannot be run inside a transaction block.
-- Run each `CREATE INDEX CONCURRENTLY` statement separately in the SQL Editor (do NOT wrap in BEGIN/COMMIT).

-- Example index for jsonb `polasci_po_danu` (uncomment to create after backfill):
-- CREATE INDEX CONCURRENTLY idx_mesecni_putnici_polasci_gin ON mesecni_putnici USING gin (polasci_po_danu jsonb_path_ops);

-- Example index for `radni_dani_arr` (text[]):
-- CREATE INDEX CONCURRENTLY idx_mesecni_putnici_radni_dani_gin ON mesecni_putnici USING gin (radni_dani_arr);

-- Example index for `statistics` jsonb:
-- CREATE INDEX CONCURRENTLY idx_mesecni_putnici_statistics_gin ON mesecni_putnici USING gin (statistics jsonb_path_ops);

-- 6) Final sanity summary (run after index creation if you like):
SELECT 'after_backfill_cena_null' AS key, count(*)::text FROM mesecni_putnici WHERE cena IS NOT NULL AND cena_numeric IS NULL;

-- End of script

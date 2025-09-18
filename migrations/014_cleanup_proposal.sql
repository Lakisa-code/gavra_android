-- migrations/014_cleanup_proposal.sql
-- Non-destructive cleanup proposal for legacy columns.
-- This file does NOT execute destructive drops automatically.
-- It outputs safety checks and DROP statements as comments to be reviewed and run manually.

-- 1) Check counts for legacy columns that might be safe to drop
SELECT
  count(*) FILTER (WHERE (radni_dani IS NOT NULL AND radni_dani <> '') OR (radni_dani_arr IS NULL)) AS legacy_radni_dani_count,
  count(*) FILTER (WHERE cena IS NOT NULL AND cena_numeric IS NULL) AS legacy_cena_only_count,
  count(*) FILTER (WHERE polasci_po_danu IS NULL OR polasci_po_danu = '{}'::jsonb) AS polasci_missing_count
FROM public.mesecni_putnici;

-- 2) If the above counts are zero (or acceptable after manual review), here are the safe DROP statements.
-- Review them, run backups/dumps, and execute them one-by-one when ready.

-- -- DROP legacy single-time columns (example)
-- ALTER TABLE public.mesecni_putnici DROP COLUMN IF EXISTS radni_dani;
-- ALTER TABLE public.mesecni_putnici DROP COLUMN IF EXISTS cena; -- only drop if cena_numeric is populated and app uses cena_numeric

-- 3) If you prefer to archive data instead of DROP, copy to an audit table first:
-- CREATE TABLE IF NOT EXISTS public.mesecni_putnici_legacy_archive AS TABLE public.mesecni_putnici WITH NO DATA;
-- INSERT INTO public.mesecni_putnici_legacy_archive (SELECT * FROM public.mesecni_putnici WHERE radni_dani IS NOT NULL OR cena IS NOT NULL);

-- 4) Final safety checklist (do these before any DROP)
-- - Run the SELECT checks above and confirm counts = 0 (or acceptably low).
-- - Create a dump/backup of `mesecni_putnici`.
-- - Ensure app clients are updated to use new fields.
-- - Run DROP statements in maintenance window.

-- To apply: copy desired DROP lines, remove '-- ' prefix, and run them manually in the SQL Editor.

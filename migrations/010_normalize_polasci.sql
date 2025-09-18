-- migrations/010_normalize_polasci.sql
-- Normalize `polasci_po_danu` to a safe empty JSON array where missing or empty
-- Idempotent: safe to run multiple times

BEGIN;

-- Ensure default exists (already set by earlier migration, but harmless to enforce)
ALTER TABLE IF EXISTS public.mesecni_putnici
  ALTER COLUMN polasci_po_danu SET DEFAULT '[]'::jsonb;

-- Normalize NULL or empty JSON objects/arrays to an empty JSON array
UPDATE public.mesecni_putnici
SET polasci_po_danu = '[]'::jsonb
WHERE polasci_po_danu IS NULL
  OR polasci_po_danu = '{}'::jsonb
  OR polasci_po_danu = '[]'::jsonb
  -- if some rows have empty-string stored as text in a jsonb column, coalesce will not match;
  -- those cases should be handled manually after inspection
;

COMMIT;

-- Return a small verification summary (run separately if your SQL runner disallows multiple statements)
SELECT
  count(*) FILTER (WHERE polasci_po_danu IS NULL) AS null_count,
  count(*) FILTER (WHERE polasci_po_danu = '{}'::jsonb) AS empty_object_count,
  count(*) FILTER (WHERE polasci_po_danu = '[]'::jsonb) AS empty_array_count,
  count(*) AS total_rows
FROM public.mesecni_putnici;

-- Verification queries for legacy `polazak_*` columns in `public.mesecni_putnici`
-- Run each statement separately (Supabase SQL editor or `psql -c`) to avoid multi-statement issues.

-- 1) Total rows that have any legacy per-day (bc or vs) non-empty value
SELECT count(*) AS rows_with_any_legacy_polazak
FROM public.mesecni_putnici
WHERE coalesce(polazak_bc_pon,'')<>'' OR coalesce(polazak_bc_uto,'')<>'' OR coalesce(polazak_bc_sre,'')<>'' OR coalesce(polazak_bc_cet,'')<>'' OR coalesce(polazak_bc_pet,'')<>'' OR
      coalesce(polazak_vs_pon,'')<>'' OR coalesce(polazak_vs_uto,'')<>'' OR coalesce(polazak_vs_sre,'')<>'' OR coalesce(polazak_vs_cet,'')<>'' OR coalesce(polazak_vs_pet,'')<>'';

-- 2) Per-column non-empty counts (one row output) -- run as-is
SELECT
  sum((coalesce(polazak_bc_pon,'')<>'')::int) AS bc_pon,
  sum((coalesce(polazak_bc_uto,'')<>'')::int) AS bc_uto,
  sum((coalesce(polazak_bc_sre,'')<>'')::int) AS bc_sre,
  sum((coalesce(polazak_bc_cet,'')<>'')::int) AS bc_cet,
  sum((coalesce(polazak_bc_pet,'')<>'')::int) AS bc_pet,
  sum((coalesce(polazak_vs_pon,'')<>'')::int) AS vs_pon,
  sum((coalesce(polazak_vs_uto,'')<>'')::int) AS vs_uto,
  sum((coalesce(polazak_vs_sre,'')<>'')::int) AS vs_sre,
  sum((coalesce(polazak_vs_cet,'')<>'')::int) AS vs_cet,
  sum((coalesce(polazak_vs_pet,'')<>'')::int) AS vs_pet
FROM public.mesecni_putnici;

-- 3) Sample rows showing legacy values alongside canonical `polasci_po_danu` (limit 10)
SELECT id, putnik_ime, polasci_po_danu, polazak_bc_pon, polazak_vs_pon, polazak_bc_uto, polazak_vs_uto
FROM public.mesecni_putnici
WHERE coalesce(polazak_bc_pon,'')<>'' OR coalesce(polazak_vs_pon,'')<>'' OR coalesce(polazak_bc_uto,'')<>'' OR coalesce(polazak_vs_uto,'')<>''
ORDER BY updated_at DESC NULLS LAST
LIMIT 10;

-- 4) Rows where `polasci_po_danu` is NULL/empty but legacy columns exist (need backfill)
SELECT count(*) AS needs_backfill_count
FROM public.mesecni_putnici
WHERE (polasci_po_danu IS NULL OR polasci_po_danu = '{}'::jsonb)
  AND (
    coalesce(polazak_bc_pon,'')<>'' OR coalesce(polazak_bc_uto,'')<>'' OR coalesce(polazak_bc_sre,'')<>'' OR coalesce(polazak_bc_cet,'')<>'' OR coalesce(polazak_bc_pet,'')<>'' OR
    coalesce(polazak_vs_pon,'')<>'' OR coalesce(polazak_vs_uto,'')<>'' OR coalesce(polazak_vs_sre,'')<>'' OR coalesce(polazak_vs_cet,'')<>'' OR coalesce(polazak_vs_pet,'')<>''
  );

-- 5) Detect possible time-suffix variants present in rows (e.g., polazak_bc_pon_time)
-- This checks for columns that may not exist in some schemas: use safe metadata query
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'mesecni_putnici' AND column_name ~ 'polazak_.*_time';

-- 6) Quick check for text `cena` vs numeric `cena_numeric` mismatches
SELECT
  sum((cena IS NOT NULL AND cena <> '')::int) AS cena_text_count,
  sum((cena_numeric IS NOT NULL)::int) AS cena_numeric_count
FROM public.mesecni_putnici;

-- End of verification checks

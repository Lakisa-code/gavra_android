-- migrations/013_final_verify.sql
-- Final verification: confirm columns, counts, and a small sample

-- Column presence
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'mesecni_putnici'
  AND column_name IN ('polasci_po_danu','radni_dani_arr','cena_numeric','statistics');

-- Counts for normalized columns
SELECT
  count(*) FILTER (WHERE polasci_po_danu IS NULL) AS polasci_null,
  count(*) FILTER (WHERE polasci_po_danu = '{}'::jsonb) AS polasci_empty_obj,
  count(*) FILTER (WHERE polasci_po_danu = '[]'::jsonb) AS polasci_empty_arr,
  count(*) FILTER (WHERE radni_dani_arr IS NULL) AS radni_dani_null,
  count(*) FILTER (WHERE cena_numeric IS NULL) AS cena_numeric_null
FROM public.mesecni_putnici;

-- Small sample of affected rows
SELECT id, putnik_ime, polasci_po_danu, radni_dani_arr, cena, cena_numeric, statistics
FROM public.mesecni_putnici
ORDER BY id
LIMIT 20;

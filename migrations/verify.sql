-- verify.sql
-- Non-destructive verification queries to run before/after migrations

-- 1) Count mesecni_putnici without polasci_po_danu
SELECT count(*) AS nepopunjeni_polasci
FROM mesecni_putnici
WHERE polasci_po_danu IS NULL OR polasci_po_danu = '{}' OR polasci_po_danu = '[]';

-- 2) Count mesecni_putnici without radni_dani_arr
SELECT count(*) AS nepopunjeni_radni_dani_arr
FROM mesecni_putnici
WHERE radni_dani_arr IS NULL OR array_length(radni_dani_arr,1) IS NULL;

-- 3) Check any rows where cena & cena_numeric mismatch
SELECT count(*) AS cena_mismatch
FROM mesecni_putnici
WHERE (cena IS NOT NULL AND cena_numeric IS NOT NULL AND (cena::text <> cena_numeric::text))
   OR (cena IS NOT NULL AND cena_numeric IS NULL);

-- 4) Count putovanja_istorija rows with status = 'nije_se_pojavio'
SELECT count(*) AS nije_se_pojavio_count FROM putovanja_istorija WHERE status = 'nije_se_pojavio';

-- 5) Quick preview of sample rows
SELECT id, putnik_ime, polasci_po_danu, radni_dani, radni_dani_arr, cena, cena_numeric
FROM mesecni_putnici
LIMIT 10;

-- 6) Verify statistics column presence and a sample
SELECT count(*) AS statistics_exists FROM information_schema.columns
WHERE table_name = 'mesecni_putnici' AND column_name = 'statistics';
SELECT id, statistics FROM mesecni_putnici LIMIT 5;

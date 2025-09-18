-- safe_verify.sql
-- Non-destructive verification that tolerates missing columns/tables

CREATE TEMP TABLE IF NOT EXISTS __verify_results (key text PRIMARY KEY, value text);
TRUNCATE TABLE __verify_results;

INSERT INTO __verify_results(key, value)
SELECT 'mesecni_putnici_exists', (CASE WHEN EXISTS(
  SELECT 1 FROM information_schema.tables
  WHERE table_schema='public' AND table_name='mesecni_putnici') THEN 'true' ELSE 'false' END);

INSERT INTO __verify_results(key, value)
SELECT 'polasci_po_danu_exists', (CASE WHEN EXISTS(
  SELECT 1 FROM information_schema.columns
  WHERE table_schema='public' AND table_name='mesecni_putnici' AND column_name='polasci_po_danu') THEN 'true' ELSE 'false' END);

INSERT INTO __verify_results(key, value)
SELECT 'radni_dani_arr_exists', (CASE WHEN EXISTS(
  SELECT 1 FROM information_schema.columns
  WHERE table_schema='public' AND table_name='mesecni_putnici' AND column_name='radni_dani_arr') THEN 'true' ELSE 'false' END);

INSERT INTO __verify_results(key, value)
SELECT 'cena_exists', (CASE WHEN EXISTS(
  SELECT 1 FROM information_schema.columns
  WHERE table_schema='public' AND table_name='mesecni_putnici' AND column_name='cena') THEN 'true' ELSE 'false' END);

INSERT INTO __verify_results(key, value)
SELECT 'cena_numeric_exists', (CASE WHEN EXISTS(
  SELECT 1 FROM information_schema.columns
  WHERE table_schema='public' AND table_name='mesecni_putnici' AND column_name='cena_numeric') THEN 'true' ELSE 'false' END);

INSERT INTO __verify_results(key, value)
SELECT 'statistics_exists', (CASE WHEN EXISTS(
  SELECT 1 FROM information_schema.columns
  WHERE table_schema='public' AND table_name='mesecni_putnici' AND column_name='statistics') THEN 'true' ELSE 'false' END);

DO $$
BEGIN
  IF (SELECT value FROM __verify_results WHERE key='polasci_po_danu_exists') = 'true' THEN
    EXECUTE $sql$
      INSERT INTO __verify_results(key,value)
      SELECT 'nepopunjeni_polasci', count(*)::text
      FROM mesecni_putnici
      WHERE polasci_po_danu IS NULL OR polasci_po_danu = '{}' OR polasci_po_danu = '[]'
    $sql$;
  ELSE
    INSERT INTO __verify_results(key,value) VALUES ('nepopunjeni_polasci','MISSING_COLUMN');
  END IF;

  IF (SELECT value FROM __verify_results WHERE key='radni_dani_arr_exists') = 'true' THEN
    EXECUTE 'INSERT INTO __verify_results(key,value) SELECT ''nepopunjeni_radni_dani_arr'', count(*)::text FROM mesecni_putnici WHERE radni_dani_arr IS NULL OR array_length(radni_dani_arr,1) IS NULL';
  ELSE
    INSERT INTO __verify_results(key,value) VALUES ('nepopunjeni_radni_dani_arr','MISSING_COLUMN');
  END IF;

  IF (SELECT value FROM __verify_results WHERE key='cena_exists') = 'true' THEN
    IF (SELECT value FROM __verify_results WHERE key='cena_numeric_exists') = 'true' THEN
      EXECUTE 'INSERT INTO __verify_results(key,value) SELECT ''cena_mismatch'', count(*)::text FROM mesecni_putnici WHERE (cena IS NOT NULL AND cena_numeric IS NOT NULL AND (cena::text <> cena_numeric::text)) OR (cena IS NOT NULL AND cena_numeric IS NULL)';
    ELSE
      EXECUTE 'INSERT INTO __verify_results(key,value) SELECT ''cena_mismatch'', count(*)::text FROM mesecni_putnici WHERE (cena IS NOT NULL AND (cena::text IS NOT NULL)) AND (1=1)';
    END IF;
  ELSE
    INSERT INTO __verify_results(key,value) VALUES ('cena_mismatch','MISSING_COLUMN');
  END IF;

  IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='putovanja_istorija') THEN
    EXECUTE 'INSERT INTO __verify_results(key,value) SELECT ''nije_se_pojavio_count'', count(*)::text FROM putovanja_istorija WHERE status = ''nije_se_pojavio''';
  ELSE
    INSERT INTO __verify_results(key,value) VALUES ('nije_se_pojavio_count','TABLE_MISSING');
  END IF;

  IF (SELECT value FROM __verify_results WHERE key='polasci_po_danu_exists') = 'true' THEN
    EXECUTE $q$
      INSERT INTO __verify_results(key,value)
      SELECT 'sample_rows', coalesce(left(json_agg(row_to_json(t))::text, 4000),'[]') FROM (
        SELECT id, putnik_ime, polasci_po_danu, radni_dani, radni_dani_arr, cena, cena_numeric
        FROM mesecni_putnici
        LIMIT 10
      ) t;
    $q$;
  ELSE
    INSERT INTO __verify_results(key,value) VALUES ('sample_rows','MISSING_COLUMN');
  END IF;

  IF (SELECT value FROM __verify_results WHERE key='statistics_exists') = 'true' THEN
    EXECUTE $q$
      INSERT INTO __verify_results(key,value)
      SELECT 'statistics_sample', coalesce(left(json_agg(row_to_json(t))::text, 4000),'[]') FROM (
        SELECT id, statistics FROM mesecni_putnici LIMIT 5
      ) t;
    $q$;
  ELSE
    INSERT INTO __verify_results(key,value) VALUES ('statistics_sample','MISSING_COLUMN');
  END IF;

END$$;

SELECT * FROM __verify_results ORDER BY key;

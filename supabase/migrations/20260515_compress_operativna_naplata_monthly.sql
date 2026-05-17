-- Opcija A: 1 red mesečne naplate po putniku
-- 1) Spoji duplikate (putnik + godina + mesec) za operativna_naplata/prihod
WITH naplata_groups AS (
  SELECT
    putnik_v3_auth_id,
    godina,
    mesec,
    SUM(COALESCE(iznos, 0)) AS sum_iznos,
    MAX(COALESCE(broj_voznji, 0)) AS max_broj_voznji
  FROM public.v3_finansije
  WHERE tip = 'prihod'
    AND kategorija = 'operativna_naplata'
    AND putnik_v3_auth_id IS NOT NULL
  GROUP BY putnik_v3_auth_id, godina, mesec
  HAVING COUNT(*) > 1
), winners AS (
  SELECT DISTINCT ON (f.putnik_v3_auth_id, f.godina, f.mesec)
    f.id,
    f.putnik_v3_auth_id,
    f.godina,
    f.mesec
  FROM public.v3_finansije f
  JOIN naplata_groups g
    ON g.putnik_v3_auth_id = f.putnik_v3_auth_id
   AND g.godina = f.godina
   AND g.mesec = f.mesec
  WHERE f.tip = 'prihod'
    AND f.kategorija = 'operativna_naplata'
  ORDER BY f.putnik_v3_auth_id, f.godina, f.mesec, f.created_at DESC, f.id DESC
)
UPDATE public.v3_finansije dst
SET
  iznos = g.sum_iznos,
  broj_voznji = g.max_broj_voznji
FROM winners w
JOIN naplata_groups g
  ON g.putnik_v3_auth_id = w.putnik_v3_auth_id
 AND g.godina = w.godina
 AND g.mesec = w.mesec
WHERE dst.id = w.id;

WITH winners AS (
  SELECT DISTINCT ON (f.putnik_v3_auth_id, f.godina, f.mesec)
    f.id,
    f.putnik_v3_auth_id,
    f.godina,
    f.mesec
  FROM public.v3_finansije f
  WHERE f.tip = 'prihod'
    AND f.kategorija = 'operativna_naplata'
    AND f.putnik_v3_auth_id IS NOT NULL
  ORDER BY f.putnik_v3_auth_id, f.godina, f.mesec, f.created_at DESC, f.id DESC
)
DELETE FROM public.v3_finansije d
USING winners w
WHERE d.tip = 'prihod'
  AND d.kategorija = 'operativna_naplata'
  AND d.putnik_v3_auth_id = w.putnik_v3_auth_id
  AND d.godina = w.godina
  AND d.mesec = w.mesec
  AND d.id <> w.id;

-- 2) Spreči buduće duplikate
CREATE UNIQUE INDEX IF NOT EXISTS ux_v3_finansije_operativna_naplata_mesec
ON public.v3_finansije (putnik_v3_auth_id, godina, mesec)
WHERE tip = 'prihod'
  AND kategorija = 'operativna_naplata'
  AND putnik_v3_auth_id IS NOT NULL;

-- Dodaj broj_mesta kolonu u voznje_log tabelu
-- Ovo omogućava praćenje koliko mesta je putnik rezervisao za svaku vožnju
-- Važno za tačan obračun plaćanja (2 mesta = 2 × 600 RSD)

ALTER TABLE voznje_log
ADD COLUMN IF NOT EXISTS broj_mesta INTEGER DEFAULT 1 NOT NULL;

COMMENT ON COLUMN voznje_log.broj_mesta IS 'Broj rezervisanih mesta za ovu vožnju/uplatu (default 1)';

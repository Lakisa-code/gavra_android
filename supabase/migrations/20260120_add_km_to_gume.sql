-- Dodaj kolone za kilometražu guma u vozila tabelu
-- Ovo omogućava praćenje koliko kilometara pređu gume što je važno za planiranje zamene

ALTER TABLE vozila
ADD COLUMN IF NOT EXISTS gume_prednje_km INTEGER,
ADD COLUMN IF NOT EXISTS gume_zadnje_km INTEGER;

COMMENT ON COLUMN vozila.gume_prednje_km IS 'Kilometraža pri zameni prednjih guma';
COMMENT ON COLUMN vozila.gume_zadnje_km IS 'Kilometraža pri zameni zadnjih guma';

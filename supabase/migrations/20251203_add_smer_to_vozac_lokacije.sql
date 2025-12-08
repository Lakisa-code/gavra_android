-- ============================================
-- MIGRACIJA: Dodaj 'smer' kolonu u vozac_lokacije
-- Omogućava filtriranje po smeru ture (BC_VS ili VS_BC)
-- ============================================

-- Dodaj kolonu 'smer' ako ne postoji
ALTER TABLE vozac_lokacije 
ADD COLUMN IF NOT EXISTS smer TEXT;

-- Index za brže pretrage po smeru
CREATE INDEX IF NOT EXISTS idx_vozac_lokacije_smer ON vozac_lokacije(smer);

-- Komentar na kolonu
COMMENT ON COLUMN vozac_lokacije.smer IS 'Smer ture: BC_VS (Bela Crkva -> Vršac) ili VS_BC (Vršac -> Bela Crkva)';

-- ============================================
-- MIGRACIJA: Dodaj 'putnici_eta' kolonu u vozac_lokacije
-- Čuva ETA za svakog putnika u optimizovanoj ruti
-- Format: { "Ime Putnika": 3, "Drugi Putnik": 8, ... } (minuti)
-- ============================================

-- Dodaj kolonu 'putnici_eta' ako ne postoji
ALTER TABLE vozac_lokacije 
ADD COLUMN IF NOT EXISTS putnici_eta JSONB DEFAULT '{}';

-- Komentar na kolonu
COMMENT ON COLUMN vozac_lokacije.putnici_eta IS 'ETA u minutama za svakog putnika u ruti. Format: {"Ime Putnika": 3, "Drugi Putnik": 8}';

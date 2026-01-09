-- =====================================================
-- MIGRACIJA: Ispravka vozac kolona u tabelama
-- Datum: 2026-01-08
-- Opis: Dodaje vozac_id (UUID) kolone i migrira postojeće podatke
-- =====================================================

-- 1. DAILY_CHECKINS TABELA
-- =====================================================

-- Dodaj vozac_id kolonu ako ne postoji
ALTER TABLE daily_checkins 
ADD COLUMN IF NOT EXISTS vozac_id UUID REFERENCES vozaci(id);

-- Migriraj postojeće podatke: konvertuj ime vozača u UUID
UPDATE daily_checkins dc
SET vozac_id = v.id
FROM vozaci v
WHERE dc.vozac = v.ime AND dc.vozac_id IS NULL;

-- Kreiraj novi UNIQUE constraint na (vozac_id, datum)
-- Prvo ukloni stari ako postoji
ALTER TABLE daily_checkins 
DROP CONSTRAINT IF EXISTS daily_checkins_vozac_datum_key;

-- Dodaj novi constraint
ALTER TABLE daily_checkins 
ADD CONSTRAINT daily_checkins_vozac_id_datum_key UNIQUE (vozac_id, datum);

-- Kreiraj indeks za brže pretrage
CREATE INDEX IF NOT EXISTS idx_daily_checkins_vozac_id ON daily_checkins(vozac_id);


-- 2. DAILY_REPORTS TABELA
-- =====================================================

-- Dodaj vozac_id kolonu ako ne postoji
ALTER TABLE daily_reports 
ADD COLUMN IF NOT EXISTS vozac_id UUID REFERENCES vozaci(id);

-- Migriraj postojeće podatke
UPDATE daily_reports dr
SET vozac_id = v.id
FROM vozaci v
WHERE dr.vozac = v.ime AND dr.vozac_id IS NULL;

-- Kreiraj indeks
CREATE INDEX IF NOT EXISTS idx_daily_reports_vozac_id ON daily_reports(vozac_id);


-- 3. VOZAC_LOKACIJE TABELA
-- =====================================================

-- Proveri tip kolone vozac_id i konvertuj u UUID ako je TEXT
DO $$
BEGIN
    -- Prvo proveri da li je kolona TEXT tipa
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vozac_lokacije' 
        AND column_name = 'vozac_id' 
        AND data_type = 'text'
    ) THEN
        -- Dodaj privremenu kolonu za UUID
        ALTER TABLE vozac_lokacije ADD COLUMN IF NOT EXISTS vozac_uuid UUID;
        
        -- Migriraj podatke: konvertuj ime u UUID
        UPDATE vozac_lokacije vl
        SET vozac_uuid = v.id
        FROM vozaci v
        WHERE vl.vozac_id = v.ime OR vl.vozac_ime = v.ime;
        
        -- Ukloni staru TEXT kolonu
        ALTER TABLE vozac_lokacije DROP COLUMN IF EXISTS vozac_id;
        
        -- Preimenuj novu kolonu
        ALTER TABLE vozac_lokacije RENAME COLUMN vozac_uuid TO vozac_id;
        
        -- Dodaj FK constraint
        ALTER TABLE vozac_lokacije 
        ADD CONSTRAINT vozac_lokacije_vozac_id_fkey 
        FOREIGN KEY (vozac_id) REFERENCES vozaci(id);
    END IF;
END $$;

-- Kreiraj UNIQUE constraint ako ne postoji
ALTER TABLE vozac_lokacije 
DROP CONSTRAINT IF EXISTS vozac_lokacije_vozac_id_key;

ALTER TABLE vozac_lokacije 
ADD CONSTRAINT vozac_lokacije_vozac_id_key UNIQUE (vozac_id);


-- =====================================================
-- VERIFIKACIJA
-- =====================================================

-- Proveri da su sve migracije uspešne
DO $$
DECLARE
    daily_checkins_count INTEGER;
    daily_reports_count INTEGER;
    vozac_lokacije_count INTEGER;
BEGIN
    -- Broj redova bez vozac_id u daily_checkins
    SELECT COUNT(*) INTO daily_checkins_count 
    FROM daily_checkins WHERE vozac_id IS NULL AND vozac IS NOT NULL;
    
    IF daily_checkins_count > 0 THEN
        RAISE WARNING 'daily_checkins: % redova bez vozac_id', daily_checkins_count;
    ELSE
        RAISE NOTICE 'daily_checkins: Migracija uspešna!';
    END IF;
    
    -- Broj redova bez vozac_id u daily_reports
    SELECT COUNT(*) INTO daily_reports_count 
    FROM daily_reports WHERE vozac_id IS NULL AND vozac IS NOT NULL;
    
    IF daily_reports_count > 0 THEN
        RAISE WARNING 'daily_reports: % redova bez vozac_id', daily_reports_count;
    ELSE
        RAISE NOTICE 'daily_reports: Migracija uspešna!';
    END IF;
    
    -- Provera vozac_lokacije
    SELECT COUNT(*) INTO vozac_lokacije_count 
    FROM vozac_lokacije WHERE vozac_id IS NULL;
    
    IF vozac_lokacije_count > 0 THEN
        RAISE WARNING 'vozac_lokacije: % redova bez vozac_id', vozac_lokacije_count;
    ELSE
        RAISE NOTICE 'vozac_lokacije: Migracija uspešna!';
    END IF;
END $$;

-- GAVRA SAMPION SQL VOZILA_ISTORIJA 2026
-- Kreiranje tabele vozila_istorija sa realtime podrškom
-- Datum: 31.01.2026

-- ===========================================
-- 1. KREIRANJE TABELE
-- ===========================================
CREATE TABLE IF NOT EXISTS vozila_istorija (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vozilo_id UUID,
    tip TEXT,
    datum DATE,
    km INTEGER,
    opis TEXT,
    cena DECIMAL(10,2),
    pozicija TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ===========================================
-- 2. KOMENTARI NA KOLONE
-- ===========================================
COMMENT ON COLUMN vozila_istorija.vozilo_id IS 'ID vozila';
COMMENT ON COLUMN vozila_istorija.tip IS 'Tip istorijskog događaja (servis, popravka, registracija, itd.)';
COMMENT ON COLUMN vozila_istorija.datum IS 'Datum događaja';
COMMENT ON COLUMN vozila_istorija.km IS 'Kilometraža vozila u vreme događaja';
COMMENT ON COLUMN vozila_istorija.opis IS 'Opis događaja';
COMMENT ON COLUMN vozila_istorija.cena IS 'Cena događaja';
COMMENT ON COLUMN vozila_istorija.pozicija IS 'Pozicija u vozilu (prednja leva guma, motor, itd.)';

-- ===========================================
-- 3. INDEXI
-- ===========================================
CREATE INDEX IF NOT EXISTS idx_vozila_istorija_vozilo_id ON vozila_istorija(vozilo_id);
CREATE INDEX IF NOT EXISTS idx_vozila_istorija_tip ON vozila_istorija(tip);
CREATE INDEX IF NOT EXISTS idx_vozila_istorija_datum ON vozila_istorija(datum);

-- ===========================================
-- 4. RLS (Row Level Security)
-- ===========================================
ALTER TABLE vozila_istorija ENABLE ROW LEVEL SECURITY;

-- Politika za čitanje - svi korisnici mogu čitati
CREATE POLICY "Enable read access for all users" ON vozila_istorija FOR SELECT USING (true);

-- Politika za insert - samo autentifikovani korisnici
CREATE POLICY "Enable insert for authenticated users" ON vozila_istorija FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

-- Politika za update - samo admin
CREATE POLICY "Enable update for admin only" ON vozila_istorija FOR UPDATE
USING (auth.role() = 'admin');

-- ===========================================
-- 5. REALTIME PUBLICATION
-- ===========================================
ALTER PUBLICATION supabase_realtime ADD TABLE vozila_istorija;
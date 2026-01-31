-- GAVRA SAMPION SQL VOZAC_LOKACIJE 2026
-- Kreiranje tabele vozac_lokacije sa realtime podrškom
-- Datum: 31.01.2026

-- ===========================================
-- 1. KREIRANJE TABELE
-- ===========================================
CREATE TABLE IF NOT EXISTS vozac_lokacije (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vozac_id UUID,
    vozac_ime TEXT,
    lat DECIMAL(10,8),
    lng DECIMAL(11,8),
    grad TEXT,
    vreme_polaska TIME,
    smer TEXT,
    putnici_eta JSONB,
    aktivan BOOLEAN DEFAULT true,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ===========================================
-- 2. KOMENTARI NA KOLONE
-- ===========================================
COMMENT ON COLUMN vozac_lokacije.vozac_id IS 'ID vozača';
COMMENT ON COLUMN vozac_lokacije.vozac_ime IS 'Ime vozača';
COMMENT ON COLUMN vozac_lokacije.lat IS 'Geografska širina lokacije vozača';
COMMENT ON COLUMN vozac_lokacije.lng IS 'Geografska dužina lokacije vozača';
COMMENT ON COLUMN vozac_lokacije.grad IS 'Grad u kojem se vozač nalazi';
COMMENT ON COLUMN vozac_lokacije.vreme_polaska IS 'Vreme polaska vozača';
COMMENT ON COLUMN vozac_lokacije.smer IS 'Smer kretanja vozača';
COMMENT ON COLUMN vozac_lokacije.putnici_eta IS 'Procenjeno vreme dolaska do putnika (JSON)';
COMMENT ON COLUMN vozac_lokacije.aktivan IS 'Da li je vozač aktivan';

-- ===========================================
-- 3. INDEXI
-- ===========================================
CREATE INDEX IF NOT EXISTS idx_vozac_lokacije_vozac_id ON vozac_lokacije(vozac_id);
CREATE INDEX IF NOT EXISTS idx_vozac_lokacije_grad ON vozac_lokacije(grad);
CREATE INDEX IF NOT EXISTS idx_vozac_lokacije_aktivan ON vozac_lokacije(aktivan);
CREATE INDEX IF NOT EXISTS idx_vozac_lokacije_lat_lng ON vozac_lokacije(lat, lng);

-- ===========================================
-- 4. RLS (Row Level Security)
-- ===========================================
ALTER TABLE vozac_lokacije ENABLE ROW LEVEL SECURITY;

-- Politika za čitanje - svi korisnici mogu čitati
CREATE POLICY "Enable read access for all users" ON vozac_lokacije FOR SELECT USING (true);

-- Politika za insert/update - samo vozač ili admin
CREATE POLICY "Enable write for driver or admin" ON vozac_lokacije FOR ALL
USING (auth.uid()::text = vozac_id::text OR auth.role() = 'admin');

-- ===========================================
-- 5. REALTIME PUBLICATION
-- ===========================================
ALTER PUBLICATION supabase_realtime ADD TABLE vozac_lokacije;
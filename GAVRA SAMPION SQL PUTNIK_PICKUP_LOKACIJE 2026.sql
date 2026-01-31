-- GAVRA SAMPION SQL PUTNIK_PICKUP_LOKACIJE 2026
-- Kreiranje tabele putnik_pickup_lokacije sa realtime podrškom
-- Datum: 31.01.2026

-- ===========================================
-- 1. KREIRANJE TABELE
-- ===========================================
CREATE TABLE IF NOT EXISTS putnik_pickup_lokacije (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    putnik_id UUID,
    putnik_ime TEXT,
    lat DECIMAL(10,8),
    lng DECIMAL(11,8),
    vozac_id UUID,
    datum DATE,
    vreme TIME,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ===========================================
-- 2. KOMENTARI NA KOLONE
-- ===========================================
COMMENT ON COLUMN putnik_pickup_lokacije.putnik_id IS 'ID registrovanog putnika';
COMMENT ON COLUMN putnik_pickup_lokacije.putnik_ime IS 'Ime putnika';
COMMENT ON COLUMN putnik_pickup_lokacije.lat IS 'Geografska širina lokacije';
COMMENT ON COLUMN putnik_pickup_lokacije.lng IS 'Geografska dužina lokacije';
COMMENT ON COLUMN putnik_pickup_lokacije.vozac_id IS 'ID vozača koji preuzima putnika';
COMMENT ON COLUMN putnik_pickup_lokacije.datum IS 'Datum preuzimanja';
COMMENT ON COLUMN putnik_pickup_lokacije.vreme IS 'Vreme preuzimanja';

-- ===========================================
-- 3. INDEXI
-- ===========================================
CREATE INDEX IF NOT EXISTS idx_putnik_pickup_lokacije_putnik_id ON putnik_pickup_lokacije(putnik_id);
CREATE INDEX IF NOT EXISTS idx_putnik_pickup_lokacije_vozac_id ON putnik_pickup_lokacije(vozac_id);
CREATE INDEX IF NOT EXISTS idx_putnik_pickup_lokacije_datum ON putnik_pickup_lokacije(datum);
CREATE INDEX IF NOT EXISTS idx_putnik_pickup_lokacije_lat_lng ON putnik_pickup_lokacije(lat, lng);

-- ===========================================
-- 4. RLS (Row Level Security)
-- ===========================================
ALTER TABLE putnik_pickup_lokacije ENABLE ROW LEVEL SECURITY;

-- Politika za čitanje - svi korisnici mogu čitati
CREATE POLICY "Enable read access for all users" ON putnik_pickup_lokacije FOR SELECT USING (true);

-- Politika za insert - samo autentifikovani korisnici
CREATE POLICY "Enable insert for authenticated users" ON putnik_pickup_lokacije FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

-- Politika za update - samo vozač ili admin
CREATE POLICY "Enable update for driver or admin" ON putnik_pickup_lokacije FOR UPDATE
USING (auth.uid()::text = vozac_id::text OR auth.role() = 'admin');

-- ===========================================
-- 5. REALTIME PUBLICATION
-- ===========================================
ALTER PUBLICATION supabase_realtime ADD TABLE putnik_pickup_lokacije;
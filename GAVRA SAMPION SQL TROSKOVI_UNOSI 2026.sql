-- GAVRA SAMPION SQL TROSKOVI_UNOSI 2026
-- Kreiranje tabele troskovi_unosi sa realtime podrškom
-- Datum: 31.01.2026

-- ===========================================
-- 1. KREIRANJE TABELE
-- ===========================================
CREATE TABLE IF NOT EXISTS troskovi_unosi (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    datum DATE NOT NULL,
    tip TEXT NOT NULL,
    iznos DECIMAL(10,2) NOT NULL,
    opis TEXT,
    vozilo_id UUID,
    vozac_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ===========================================
-- 2. KOMENTARI NA KOLONE
-- ===========================================
COMMENT ON COLUMN troskovi_unosi.datum IS 'Datum troška';
COMMENT ON COLUMN troskovi_unosi.tip IS 'Tip troška (gorivo, održavanje, itd.)';
COMMENT ON COLUMN troskovi_unosi.iznos IS 'Iznos troška u RSD';
COMMENT ON COLUMN troskovi_unosi.opis IS 'Opis troška';
COMMENT ON COLUMN troskovi_unosi.vozilo_id IS 'ID vozila na koje se trošak odnosi';
COMMENT ON COLUMN troskovi_unosi.vozac_id IS 'ID vozača koji je uneo trošak';

-- ===========================================
-- 3. CONSTRAINTS
-- ===========================================
ALTER TABLE troskovi_unosi ADD CONSTRAINT check_iznos_positive
    CHECK (iznos > 0);

-- ===========================================
-- 4. INDEXI
-- ===========================================
CREATE INDEX IF NOT EXISTS idx_troskovi_unosi_datum ON troskovi_unosi(datum);
CREATE INDEX IF NOT EXISTS idx_troskovi_unosi_tip ON troskovi_unosi(tip);
CREATE INDEX IF NOT EXISTS idx_troskovi_unosi_vozilo_id ON troskovi_unosi(vozilo_id);
CREATE INDEX IF NOT EXISTS idx_troskovi_unosi_vozac_id ON troskovi_unosi(vozac_id);

-- ===========================================
-- 5. RLS (Row Level Security)
-- ===========================================
ALTER TABLE troskovi_unosi ENABLE ROW LEVEL SECURITY;

-- Politika za čitanje - svi korisnici mogu čitati
CREATE POLICY "Enable read access for all users" ON troskovi_unosi FOR SELECT USING (true);

-- Politika za insert - samo autentifikovani korisnici
CREATE POLICY "Enable insert for authenticated users" ON troskovi_unosi FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

-- Politika za update - samo vozač koji je uneo ili admin
CREATE POLICY "Enable update for expense owner or admin" ON troskovi_unosi FOR UPDATE
USING (auth.uid()::text = vozac_id::text OR auth.role() = 'admin');

-- ===========================================
-- 6. REALTIME PUBLICATION
-- ===========================================
ALTER PUBLICATION supabase_realtime ADD TABLE troskovi_unosi;
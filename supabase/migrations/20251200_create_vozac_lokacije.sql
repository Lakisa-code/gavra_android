-- ============================================
-- TABELA: vozac_lokacije
-- Real-time GPS lokacija vozača za praćenje od strane putnika
-- ============================================

CREATE TABLE IF NOT EXISTS vozac_lokacije (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vozac_id TEXT NOT NULL,                    -- Ime vozača (Bojan, Vlajic, itd.)
    vozac_ime TEXT,                            -- Puno ime vozača za prikaz
    lat DOUBLE PRECISION NOT NULL,             -- Latitude
    lng DOUBLE PRECISION NOT NULL,             -- Longitude
    grad TEXT NOT NULL DEFAULT 'Bela Crkva',   -- BC ili Vršac - koja ruta
    vreme_polaska TEXT,                        -- Vreme polaska (5:00, 6:00, itd.)
    aktivan BOOLEAN DEFAULT TRUE,              -- Da li je vozač aktivan na ruti
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index za brže pretrage po vozaču i aktivnosti
CREATE INDEX IF NOT EXISTS idx_vozac_lokacije_vozac ON vozac_lokacije(vozac_id);
CREATE INDEX IF NOT EXISTS idx_vozac_lokacije_aktivan ON vozac_lokacije(aktivan);
CREATE INDEX IF NOT EXISTS idx_vozac_lokacije_grad ON vozac_lokacije(grad);

-- Omogući Realtime za ovu tabelu
ALTER PUBLICATION supabase_realtime ADD TABLE vozac_lokacije;

-- RLS Politike
ALTER TABLE vozac_lokacije ENABLE ROW LEVEL SECURITY;

-- Svi mogu čitati (putnici treba da vide lokaciju)
CREATE POLICY "Svi mogu čitati lokacije vozača"
ON vozac_lokacije FOR SELECT
USING (true);

-- Samo autentifikovani korisnici mogu upisivati/ažurirati
CREATE POLICY "Autentifikovani mogu upisivati"
ON vozac_lokacije FOR INSERT
WITH CHECK (true);

CREATE POLICY "Autentifikovani mogu ažurirati"
ON vozac_lokacije FOR UPDATE
USING (true);

-- Trigger za automatsko ažuriranje updated_at
CREATE OR REPLACE FUNCTION update_vozac_lokacije_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER vozac_lokacije_updated_at
    BEFORE UPDATE ON vozac_lokacije
    FOR EACH ROW
    EXECUTE FUNCTION update_vozac_lokacije_updated_at();

-- Komentar na tabelu
COMMENT ON TABLE vozac_lokacije IS 'Real-time GPS lokacije vozača za praćenje od strane mesečnih putnika';

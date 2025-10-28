-- 🔥 KREIRANJE TABELE KORISNICI ZA FIREBASE AUTH + SUPABASE DATA
-- Pokreni ovu skriptu u Supabase SQL Editor

CREATE TABLE IF NOT EXISTS korisnici (
    id BIGSERIAL PRIMARY KEY,
    firebase_uid TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    vozac_name TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Indeksi za bolje performanse
CREATE INDEX IF NOT EXISTS idx_korisnici_firebase_uid ON korisnici(firebase_uid);
CREATE INDEX IF NOT EXISTS idx_korisnici_email ON korisnici(email);
CREATE INDEX IF NOT EXISTS idx_korisnici_vozac_name ON korisnici(vozac_name);
CREATE INDEX IF NOT EXISTS idx_korisnici_active ON korisnici(is_active);

-- RLS (Row Level Security) politike
ALTER TABLE korisnici ENABLE ROW LEVEL SECURITY;

-- Politika: Korisnici mogu da vide samo svoje podatke
CREATE POLICY "Korisnici mogu da vide svoje podatke" ON korisnici
    FOR SELECT USING (firebase_uid = auth.uid()::text);

-- Politika: Korisnici mogu da ažuriraju svoje podatke
CREATE POLICY "Korisnici mogu da ažuriraju svoje podatke" ON korisnici
    FOR UPDATE USING (firebase_uid = auth.uid()::text);

-- Funkcija za automatsko ažuriranje updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger za automatsko ažuriranje updated_at
CREATE TRIGGER update_korisnici_updated_at
    BEFORE UPDATE ON korisnici
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Komentari za dokumentaciju
COMMENT ON TABLE korisnici IS 'Tabela korisnika koji koriste Firebase Auth za autentifikaciju';
COMMENT ON COLUMN korisnici.firebase_uid IS 'Jedinstveni Firebase Auth UID';
COMMENT ON COLUMN korisnici.email IS 'Email adresa korisnika';
COMMENT ON COLUMN korisnici.vozac_name IS 'Ime vozača (Svetlana, Bruda, Bilevski, Bojan)';
COMMENT ON COLUMN korisnici.is_active IS 'Da li je korisnički nalog aktivan';
COMMENT ON COLUMN korisnici.metadata IS 'Dodatni podaci u JSON formatu';
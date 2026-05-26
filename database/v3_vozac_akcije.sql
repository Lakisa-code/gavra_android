-- Kreiranje tabele v3_vozac_akcije
-- Tabela za praćenje svih akcija vozača: pokupljeni putnici i naplate

CREATE TABLE IF NOT EXISTS v3_vozac_akcije (
    id TEXT PRIMARY KEY,
    vozac_id TEXT NOT NULL,
    vozac_ime TEXT NOT NULL,
    datum TIMESTAMP NOT NULL,
    tip_akcije TEXT NOT NULL CHECK (tip_akcije IN ('pokupio', 'naplata')),
    putnik_id TEXT NOT NULL,
    putnik_ime TEXT NOT NULL,
    iznos DECIMAL(10,2) DEFAULT 0.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT
);

-- Kreiranje indeksa za brže upite
CREATE INDEX IF NOT EXISTS idx_vozac_akcije_vozac_id ON v3_vozac_akcije(vozac_id);
CREATE INDEX IF NOT EXISTS idx_vozac_akcije_datum ON v3_vozac_akcije(datum);
CREATE INDEX IF NOT EXISTS idx_vozac_akcije_tip_akcije ON v3_vozac_akcije(tip_akcije);
CREATE INDEX IF NOT EXISTS idx_vozac_akcije_vozac_datum ON v3_vozac_akcije(vozac_id, datum);
CREATE INDEX IF NOT EXISTS idx_vozac_akcije_vozac_datum_tip ON v3_vozac_akcije(vozac_id, datum, tip_akcije);
CREATE INDEX IF NOT EXISTS idx_vozac_akcije_putnik_id ON v3_vozac_akcije(putnik_id);
CREATE INDEX IF NOT EXISTS idx_vozac_akcije_created_at ON v3_vozac_akcije(created_at);

-- RLS (Row Level Security) politike
ALTER TABLE v3_vozac_akcije ENABLE ROW LEVEL SECURITY;

-- Politika za čitanje (svi korisnici mogu da čitaju)
CREATE POLICY "Svi mogu da citaju vozac akcije" ON v3_vozac_akcije
    FOR SELECT USING (true);

-- Politika za insert (samo autentifikovani korisnici)
CREATE POLICY "Samo autentifikovani mogu da insertuju vozac akcije" ON v3_vozac_akcije
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Politika za update (samo autentifikovani korisnici)
CREATE POLICY "Samo autentifikovani mogu da update-uju vozac akcije" ON v3_vozac_akcije
    FOR UPDATE USING (auth.role() = 'authenticated');

-- Politika za delete (samo autentifikovani korisnici)
CREATE POLICY "Samo autentifikovani mogu da delete-uju vozac akcije" ON v3_vozac_akcije
    FOR DELETE USING (auth.role() = 'authenticated');

-- Triger za automatsko postavljanje created_at
CREATE OR REPLACE FUNCTION set_current_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.created_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER set_vozac_akcije_created_at
    BEFORE INSERT ON v3_vozac_akcije
    FOR EACH ROW
    EXECUTE FUNCTION set_current_timestamp();

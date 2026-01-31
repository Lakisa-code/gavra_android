-- GAVRA SAMPION SQL RACUN_SEQUENCE 2026
-- Kreiranje tabele racun_sequence sa realtime podrškom
-- Datum: 31.01.2026

-- ===========================================
-- 1. KREIRANJE TABELE
-- ===========================================
CREATE TABLE IF NOT EXISTS racun_sequence (
    godina INTEGER PRIMARY KEY,
    poslednji_broj INTEGER DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ===========================================
-- 2. KOMENTARI NA KOLONE
-- ===========================================
COMMENT ON COLUMN racun_sequence.godina IS 'Godina za koju se vodi sekvenca računa';
COMMENT ON COLUMN racun_sequence.poslednji_broj IS 'Poslednji dodeljeni broj računa za tu godinu';

-- ===========================================
-- 3. RLS (Row Level Security)
-- ===========================================
ALTER TABLE racun_sequence ENABLE ROW LEVEL SECURITY;

-- Politika za čitanje - svi korisnici mogu čitati
CREATE POLICY "Enable read access for all users" ON racun_sequence FOR SELECT USING (true);

-- Politika za insert/update - samo admin
CREATE POLICY "Enable write for admin only" ON racun_sequence FOR ALL
USING (auth.role() = 'admin');

-- ===========================================
-- 4. REALTIME PUBLICATION
-- ===========================================
ALTER PUBLICATION supabase_realtime ADD TABLE racun_sequence;
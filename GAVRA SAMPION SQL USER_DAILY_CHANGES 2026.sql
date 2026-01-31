-- GAVRA SAMPION SQL USER_DAILY_CHANGES 2026
-- Kreiranje tabele user_daily_changes sa realtime podrškom
-- Datum: 31.01.2026

-- ===========================================
-- 1. KREIRANJE TABELE
-- ===========================================
CREATE TABLE IF NOT EXISTS user_daily_changes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    putnik_id UUID,
    datum DATE,
    changes_count INTEGER DEFAULT 0,
    last_change_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ===========================================
-- 2. KOMENTARI NA KOLONE
-- ===========================================
COMMENT ON COLUMN user_daily_changes.putnik_id IS 'ID putnika';
COMMENT ON COLUMN user_daily_changes.datum IS 'Datum za koji se prate promene';
COMMENT ON COLUMN user_daily_changes.changes_count IS 'Broj promena u toku dana';
COMMENT ON COLUMN user_daily_changes.last_change_at IS 'Vreme poslednje promene';

-- ===========================================
-- 3. INDEXI
-- ===========================================
CREATE INDEX IF NOT EXISTS idx_user_daily_changes_putnik_id ON user_daily_changes(putnik_id);
CREATE INDEX IF NOT EXISTS idx_user_daily_changes_datum ON user_daily_changes(datum);
CREATE INDEX IF NOT EXISTS idx_user_daily_changes_putnik_datum ON user_daily_changes(putnik_id, datum);

-- ===========================================
-- 4. RLS (Row Level Security)
-- ===========================================
ALTER TABLE user_daily_changes ENABLE ROW LEVEL SECURITY;

-- Politika za čitanje - svi korisnici mogu čitati
CREATE POLICY "Enable read access for all users" ON user_daily_changes FOR SELECT USING (true);

-- Politika za insert/update - samo admin (sistemska tabela)
CREATE POLICY "Enable write for admin only" ON user_daily_changes FOR ALL
USING (auth.role() = 'admin');

-- ===========================================
-- 5. REALTIME PUBLICATION
-- ===========================================
ALTER PUBLICATION supabase_realtime ADD TABLE user_daily_changes;
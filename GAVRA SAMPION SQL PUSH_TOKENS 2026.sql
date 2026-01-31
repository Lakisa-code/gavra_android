-- GAVRA SAMPION SQL PUSH_TOKENS 2026
-- Kreiranje tabele push_tokens sa realtime podrškom
-- Datum: 31.01.2026

-- ===========================================
-- 1. KREIRANJE TABELE
-- ===========================================
CREATE TABLE IF NOT EXISTS push_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider TEXT NOT NULL,
    token TEXT NOT NULL,
    user_id TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    user_type TEXT NOT NULL,
    putnik_id UUID,
    vozac_id UUID
);

-- ===========================================
-- 2. KOMENTARI NA KOLONE
-- ===========================================
COMMENT ON COLUMN push_tokens.provider IS 'Push provider: fcm (Android) ili apns (iOS)';
COMMENT ON COLUMN push_tokens.token IS 'Vrednost push tokena';
COMMENT ON COLUMN push_tokens.user_id IS 'Referenca na korisnika';
COMMENT ON COLUMN push_tokens.user_type IS 'Tip korisnika: putnik ili vozac';
COMMENT ON COLUMN push_tokens.putnik_id IS 'ID putnika (ako je putnik)';
COMMENT ON COLUMN push_tokens.vozac_id IS 'ID vozača (ako je vozač)';

-- ===========================================
-- 3. CONSTRAINTS
-- ===========================================
ALTER TABLE push_tokens ADD CONSTRAINT check_provider
    CHECK (provider IN ('fcm', 'apns'));

ALTER TABLE push_tokens ADD CONSTRAINT check_user_type
    CHECK (user_type IN ('putnik', 'vozac'));

-- ===========================================
-- 4. INDEXI
-- ===========================================
CREATE INDEX IF NOT EXISTS idx_push_tokens_user_id ON push_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_push_tokens_provider ON push_tokens(provider);
CREATE INDEX IF NOT EXISTS idx_push_tokens_user_type ON push_tokens(user_type);
CREATE INDEX IF NOT EXISTS idx_push_tokens_putnik_id ON push_tokens(putnik_id);
CREATE INDEX IF NOT EXISTS idx_push_tokens_vozac_id ON push_tokens(vozac_id);

-- ===========================================
-- 5. RLS (Row Level Security)
-- ===========================================
ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;

-- Politika za čitanje - svi korisnici mogu čitati
CREATE POLICY "Enable read access for all users" ON push_tokens FOR SELECT USING (true);

-- Politika za insert - samo autentifikovani korisnici
CREATE POLICY "Enable insert for authenticated users" ON push_tokens FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

-- Politika za update - samo vlasnik tokena ili admin
CREATE POLICY "Enable update for token owner" ON push_tokens FOR UPDATE
USING (auth.uid()::text = user_id);

-- ===========================================
-- 6. REALTIME PUBLICATION
-- ===========================================
ALTER PUBLICATION supabase_realtime ADD TABLE push_tokens;

-- ===========================================
-- 7. VALIDACIJA
-- ===========================================
-- Provera da li je tabela kreirana
SELECT 'Tabela push_tokens uspešno kreirana' as status
WHERE EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'push_tokens'
);

-- Provera realtime publication
SELECT 'Realtime aktivan za push_tokens' as realtime_status
WHERE EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
    AND tablename = 'push_tokens'
);
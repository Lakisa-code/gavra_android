-- Kreiraj push_players tabelu za push notifikacije
-- Pokreni ovo u Supabase SQL Editor

-- 1. Kreiraj tabelu
CREATE TABLE IF NOT EXISTS push_players (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id text,
  player_id text,
  provider text,
  platform text,
  last_seen timestamptz DEFAULT now(),
  is_active boolean DEFAULT true,
  removed_at timestamptz DEFAULT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- 2. Kreiraj indekse
CREATE INDEX IF NOT EXISTS idx_push_players_driver_id ON push_players(driver_id);
CREATE INDEX IF NOT EXISTS idx_push_players_player_id ON push_players(player_id);
CREATE INDEX IF NOT EXISTS idx_push_players_provider ON push_players(provider);
CREATE INDEX IF NOT EXISTS idx_push_players_is_active ON push_players(is_active);

-- 3. Kreiraj trigger funkciju
CREATE OR REPLACE FUNCTION update_push_players_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Kreiraj trigger
DROP TRIGGER IF EXISTS trg_update_push_players_updated_at ON push_players;
CREATE TRIGGER trg_update_push_players_updated_at
  BEFORE UPDATE ON push_players
  FOR EACH ROW
  EXECUTE FUNCTION update_push_players_updated_at();

-- 5. Testiraj tabelu
SELECT 
    table_name, 
    column_name, 
    data_type 
FROM information_schema.columns 
WHERE table_name = 'push_players' 
ORDER BY ordinal_position;

-- 6. Dodaj test red ako je potrebno
INSERT INTO push_players (driver_id, player_id, provider, platform) 
VALUES ('test_driver', 'test_token_123', 'fcm', 'android')
ON CONFLICT DO NOTHING;

-- 7. Prikaži rezultat
SELECT 'push_players tabela je uspešno kreirana!' as status;
SELECT * FROM push_players LIMIT 5;
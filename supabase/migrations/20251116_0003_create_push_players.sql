-- 2025-11-16 Create push_players table
-- Purpose: Support multiple push providers (FCM, Huawei) and provide a common table for push tokens.

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

CREATE INDEX IF NOT EXISTS idx_push_players_driver_id ON push_players(driver_id);
CREATE INDEX IF NOT EXISTS idx_push_players_player_id ON push_players(player_id);
CREATE INDEX IF NOT EXISTS idx_push_players_provider ON push_players(provider);
CREATE INDEX IF NOT EXISTS idx_push_players_is_active ON push_players(is_active);

-- Optional migration: If you have a legacy push provider table (e.g., a table from a deprecated provider),
-- consider running a manual migration to copy those rows into `push_players`.
-- Example (manual):
-- INSERT INTO push_players (driver_id, player_id, provider, platform, created_at, updated_at, last_seen, is_active)
-- SELECT driver_id, player_id, 'legacy', platform, created_at, updated_at, updated_at, COALESCE(is_active, true)
-- FROM legacy_push_provider_table
-- ON CONFLICT (driver_id, player_id) DO NOTHING;

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_push_players_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_push_players_updated_at ON push_players;
CREATE TRIGGER trg_update_push_players_updated_at
  BEFORE UPDATE ON push_players
  FOR EACH ROW
  EXECUTE FUNCTION update_push_players_updated_at();

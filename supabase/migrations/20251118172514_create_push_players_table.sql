-- Create push_players table for push notifications
-- 2025-11-18: Final migration to fix 404 error in push service

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

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_push_players_driver_id ON push_players(driver_id);
CREATE INDEX IF NOT EXISTS idx_push_players_player_id ON push_players(player_id);
CREATE INDEX IF NOT EXISTS idx_push_players_provider ON push_players(provider);
CREATE INDEX IF NOT EXISTS idx_push_players_is_active ON push_players(is_active);

-- Create trigger function to auto-update updated_at
CREATE OR REPLACE FUNCTION update_push_players_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trg_update_push_players_updated_at ON push_players;
CREATE TRIGGER trg_update_push_players_updated_at
  BEFORE UPDATE ON push_players
  FOR EACH ROW
  EXECUTE FUNCTION update_push_players_updated_at();
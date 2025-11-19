-- Apply push_players migration manually
-- Run this SQL directly in your Supabase SQL Editor

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

-- Verify the table was created
SELECT 'push_players table created successfully' as status;
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

const SUPABASE_URL = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

async function applyMigration() {
    console.log('🔧 Primenjujem push_players migraciju...');

    // Try with service role key first
    const adminClient = SUPABASE_SERVICE_ROLE_KEY
        ? createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
        : createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

    console.log('🔑 Koristim:', SUPABASE_SERVICE_ROLE_KEY ? 'Service Role' : 'Anon key');

    try {
        // Create the table with raw SQL query using REST API
        const sql = `
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
        `;

        // Use direct HTTP call to execute SQL
        const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/exec_sql`, {
            method: 'POST',
            headers: {
                'apikey': SUPABASE_SERVICE_ROLE_KEY || SUPABASE_ANON_KEY,
                'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY || SUPABASE_ANON_KEY}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ sql })
        });

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${await response.text()}`);
        }

        const result = await response.json();
        console.log('📊 SQL izvršen:', result);

        // Test the table
        const { data: testData, error: testError } = await adminClient
            .from('push_players')
            .select('*')
            .limit(1);

        if (testError) {
            console.log('❌ Test tabele neuspešan:', testError.message);
        } else {
            console.log('✅ push_players tabela je uspešno kreirana!');
            console.log('🎉 Push token registracija će sada raditi');
        }

    } catch (error) {
        console.log('❌ Greška pri kreiranju tabele:', error.message);
        console.log('💡 Pokušajte ručno u Supabase Dashboard > SQL Editor');
        console.log(`
📋 SQL za copy/paste:

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
        `);
    }
}

applyMigration();
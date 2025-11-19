import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

async function createPushPlayersTable() {
    console.log('🔧 Kreiranje push_players tabele...');

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

    try {
        // Create the table using RPC call
        const createTableSQL = `
            -- Create push_players table
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

            -- Create indexes
            CREATE INDEX IF NOT EXISTS idx_push_players_driver_id ON push_players(driver_id);
            CREATE INDEX IF NOT EXISTS idx_push_players_player_id ON push_players(player_id);
            CREATE INDEX IF NOT EXISTS idx_push_players_provider ON push_players(provider);
            CREATE INDEX IF NOT EXISTS idx_push_players_is_active ON push_players(is_active);

            -- Create trigger function
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
        `;

        // Execute the SQL
        const { data, error } = await supabase.rpc('exec_sql', { sql: createTableSQL });

        if (error) {
            console.log('❌ Greška pri kreiranju tabele:', error.message);

            // Try alternative approach - create table step by step
            console.log('🔄 Pokušavam alternativni pristup...');

            // Just try to create a simple table first
            const { error: createError } = await supabase.rpc('exec_sql', {
                sql: `CREATE TABLE IF NOT EXISTS push_players (
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
                );`
            });

            if (createError) {
                console.log('❌ Ne mogu da kreiram tabelu preko RPC-a:', createError.message);
                console.log('💡 Molimo pokrenite SQL ručno u Supabase SQL Editor-u');
                return;
            }
        }

        // Verify table was created
        const { data: testData, error: testError } = await supabase
            .from('push_players')
            .select('*')
            .limit(1);

        if (testError) {
            console.log('❌ Tabela nije kreirana uspešno:', testError.message);
        } else {
            console.log('✅ push_players tabela je uspešno kreirana!');
            console.log('🎉 Push token registracija će sada raditi bez grešaka');
        }

    } catch (error) {
        console.log('💥 Neočekivana greška:', error.message);
        console.log('💡 Molimo pokrenite SQL ručno u Supabase SQL Editor-u');
    }
}

createPushPlayersTable();
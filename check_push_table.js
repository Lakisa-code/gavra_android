import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

async function checkPushPlayersTable() {
    console.log('🔍 Proverava da li push_players tabela postoji...');

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

    try {
        // Try to query the push_players table
        const { data, error } = await supabase
            .from('push_players')
            .select('*')
            .limit(1);

        if (error) {
            if (error.message.includes('does not exist') || error.code === '42P01') {
                console.log('❌ push_players tabela ne postoji');
                console.log('💡 Treba da pokrenete migraciju iz apply_push_migration.sql');
                return false;
            } else {
                console.log('⚠️ Greška pri pristupanju push_players tabeli:', error.message);
                return false;
            }
        } else {
            console.log('✅ push_players tabela postoji');
            console.log(`📊 Broj redova u tabeli: ${data?.length || 0}`);
            return true;
        }
    } catch (e) {
        console.log('❌ Neočekivana greška:', e.message);
        return false;
    }
}

checkPushPlayersTable();
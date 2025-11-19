import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

async function testSupabaseConnection() {
    console.log('🧪 Testiranje Supabase konekcije...');

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

    try {
        // Test basic connection
        console.log('1️⃣ Testiranje osnovne konekcije...');
        const { data: version } = await supabase.rpc('version');
        console.log('✅ Supabase konekcija uspešna');

        // Test vozaci table
        console.log('2️⃣ Testiranje tabele vozaci...');
        const { data: vozaci, error: vozaciError } = await supabase
            .from('vozaci')
            .select('ime, kusur')
            .limit(3);

        if (vozaciError) {
            console.log('❌ Greška pri čitanju vozaca:', vozaciError.message);
        } else {
            console.log('✅ Vozaci uspešno učitani:', vozaci?.length, 'vozača');
            vozaci?.forEach(v => console.log(`  - ${v.ime}: ${v.kusur} RSD`));
        }

        // Test RPC function
        console.log('3️⃣ Testiranje RPC funkcije get_vozac_kusur...');
        const { data: kusur, error: kusurError } = await supabase
            .rpc('get_vozac_kusur', { p_vozac_ime: 'Bojan' });

        if (kusurError) {
            console.log('❌ Greška pri RPC pozivu:', kusurError.message);
        } else {
            console.log('✅ RPC funkcija radi, kusur za Bojan:', kusur, 'RSD');
        }

        // Test push_players table
        console.log('4️⃣ Testiranje push_players tabele...');
        const { data: pushData, error: pushError } = await supabase
            .from('push_players')
            .select('*')
            .limit(1);

        if (pushError) {
            if (pushError.message.includes('does not exist') || pushError.code === '42P01') {
                console.log('❌ push_players tabela ne postoji - treba migracija!');
                console.log('💡 Pokrenite SQL iz apply_push_migration.sql u Supabase dashboard-u');
            } else {
                console.log('⚠️ Greška pri pristupanju push_players tabeli:', pushError.message);
            }
        } else {
            console.log('✅ push_players tabela postoji');
            console.log('📊 Broj test redova:', pushData?.length || 0);
        }

    } catch (error) {
        console.log('❌ Opšta greška:', error);
    }
}

testSupabaseConnection();
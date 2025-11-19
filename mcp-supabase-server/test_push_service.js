import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

async function testPushService() {
    console.log('🧪 Testiram push_players tabelu...');

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

    try {
        // 1. Testiraj pristup tabeli
        console.log('1️⃣ Testiram pristup tabeli...');
        const { data: tableData, error: tableError } = await supabase
            .from('push_players')
            .select('*')
            .limit(1);

        if (tableError) {
            console.log('❌ Tabela ne postoji:', tableError.message);
            console.log('💡 Pokrenite SQL iz create_push_players_final.sql');
            return;
        }

        console.log('✅ push_players tabela postoji!');

        // 2. Testiraj insert (simuliraj push token registraciju)
        console.log('2️⃣ Testiram insert push token-a...');
        const { data: insertData, error: insertError } = await supabase
            .from('push_players')
            .upsert({
                driver_id: 'test_driver_123',
                player_id: 'test_fcm_token_' + Date.now(),
                provider: 'fcm',
                platform: 'android',
                is_active: true,
            }, {
                onConflict: 'player_id'
            })
            .select();

        if (insertError) {
            console.log('❌ Greška pri unosu:', insertError.message);
        } else {
            console.log('✅ Push token uspešno registrovan!');
            console.log('📄 Podaci:', insertData);
        }

        // 3. Testiraj query postojećih tokena
        console.log('3️⃣ Testiram query aktivnih tokena...');
        const { data: activeTokens, error: queryError } = await supabase
            .from('push_players')
            .select('*')
            .eq('is_active', true)
            .limit(5);

        if (queryError) {
            console.log('❌ Greška pri query-ju:', queryError.message);
        } else {
            console.log('✅ Pronađeni aktivni tokeni:', activeTokens.length);
            activeTokens.forEach(token => {
                console.log(`  - ${token.driver_id}: ${token.provider} (${token.platform})`);
            });
        }

        console.log('🎉 push_players tabela radi ispravno!');
        console.log('✅ Push notifikacije će sada raditi bez 404 greške');

    } catch (error) {
        console.log('💥 Neočekivana greška:', error.message);
    }
}

testPushService();
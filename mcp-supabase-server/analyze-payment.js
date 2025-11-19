import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
    'https://gjtabtwudbrmfeyjiicu.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk'
);

async function analyzePayment() {
    console.log('🔍 Analiza plaćanja Mihaj Anastasija...\n');

    // 1. Sva plaćanja za Mihaj Anastasija
    const { data: payments, error } = await supabase
        .from('putovanja_istorija')
        .select('*')
        .eq('putnik_ime', 'Mihaj Anastasija')
        .order('created_at', { ascending: false });

    if (error) {
        console.log('❌ Greška:', error.message);
        return;
    }

    console.log(`💰 Ukupno plaćanja za Mihaj Anastasija: ${payments.length}\n`);

    payments.forEach((p, i) => {
        console.log(`${i + 1}. PLAĆANJE:`);
        console.log(`   Datum: ${p.datum_putovanja}`);
        console.log(`   Cena: ${p.cena} RSD`);
        console.log(`   VozacID: ${p.vozac_id || 'NULL'}`);
        console.log(`   CreatedBy: ${p.created_by || 'NULL'}`);
        console.log(`   Napomene: ${p.napomene}`);
        if (p.action_log) {
            console.log(`   ActionLog: ${JSON.stringify(p.action_log).substring(0, 100)}...`);
        }
        console.log('');
    });

    // 2. Ko je trebalo da naplati?
    console.log('📋 ANALIZA PROBLEMA:');
    console.log('- "Mihaj Anastasija" je IME PUTNIKA, ne vozača');
    console.log('- Sistem pokušava da nađe vozača sa tim imenom');
    console.log('- Vozač koji je naplatio nije pravilno identifikovan');
    console.log('\n❓ KO JE STVARNO NAPLATIO?');
    console.log('- Proveriti ko je bio prijavljen tokom plaćanja');
    console.log('- Možda je problem u AuthManager.getCurrentDriver()');
}

analyzePayment().catch(console.error);
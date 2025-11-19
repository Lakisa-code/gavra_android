import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
    'https://gjtabtwudbrmfeyjiicu.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk'
);

async function checkDatabase() {
    console.log('🔍 Direktna provera Supabase baze...\n');

    // 1. Proveri vozače
    console.log('1️⃣ VOZACI TABELA:');
    const { data: vozaci, error: vozaciError } = await supabase
        .from('vozaci')
        .select('*')
        .order('ime');

    if (vozaciError) {
        console.log('❌ Greška pri čitanju vozaca:', vozaciError.message);
    } else {
        console.log(`📊 Ukupno vozača: ${vozaci.length}`);
        vozaci.forEach(v => {
            console.log(`  - ${v.ime} (ID: ${v.id.substring(0, 8)}...) aktivan: ${v.aktivan} kusur: ${v.kusur}`);
        });
    }

    console.log('\n2️⃣ PUTOVANJA ISTORIJA - POSLEDNJA PLAĆANJA:');
    const { data: putovanja, error: putovanjaError } = await supabase
        .from('putovanja_istorija')
        .select('putnik_ime, datum_putovanja, cena, vozac_id, napomene')
        .eq('status', 'placeno')
        .order('created_at', { ascending: false })
        .limit(5);

    if (putovanjaError) {
        console.log('❌ Greška pri čitanju putovanja:', putovanjaError.message);
    } else {
        console.log(`📊 Poslednja ${putovanja.length} plaćanja:`);
        putovanja.forEach(p => {
            console.log(`  - ${p.putnik_ime}: ${p.cena} RSD (vozac_id: ${p.vozac_id ? p.vozac_id.substring(0, 8) : 'NULL'}...)`);
            if (p.napomene && p.napomene.includes('vozač nije u bazi')) {
                console.log(`    ⚠️ ${p.napomene}`);
            }
        });
    }

    console.log('\n3️⃣ TESTIRANJE RPC FUNKCIJA:');

    // Test kusur funkciju
    const { data: kusurBojan, error: kusurError } = await supabase
        .rpc('get_vozac_kusur', { p_vozac_ime: 'Bojan' });

    if (kusurError) {
        console.log('❌ RPC get_vozac_kusur greška:', kusurError.message);
    } else {
        console.log(`✅ RPC get_vozac_kusur('Bojan'): ${kusurBojan} RSD`);
    }

    // Test da li 'Mihaj Anastasija' postoji u bazi
    const { data: mihaj, error: mihajError } = await supabase
        .from('vozaci')
        .select('*')
        .or('ime.eq.Mihaj Anastasija,ime.ilike.%mihaj%,ime.ilike.%anastasija%')
        .limit(5);

    if (mihajError) {
        console.log('❌ Pretraga Mihaj Anastasija greška:', mihajError.message);
    } else {
        console.log(`🔍 Pretraga 'Mihaj Anastasija': ${mihaj.length} rezultata`);
        mihaj.forEach(m => console.log(`  - ${m.ime} (aktivan: ${m.aktivan})`));
    }
}

checkDatabase().catch(console.error);
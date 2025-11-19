import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
    'https://gjtabtwudbrmfeyjiicu.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk'
);

async function checkTableStructure() {
    console.log('🔍 Proverava strukturu vozaci tabele...\n');

    // Test 1: Dobij sve kolone (SELECT *)
    console.log('1️⃣ Test sa SELECT *:');
    const { data: allColumns, error: allError } = await supabase
        .from('vozaci')
        .select('*')
        .limit(1);

    if (allError) {
        console.log('❌ Greška sa SELECT *:', allError.message);
    } else {
        console.log('✅ SELECT * radi. Kolone u tabeli:');
        if (allColumns && allColumns.length > 0) {
            Object.keys(allColumns[0]).forEach(col => console.log(`  - ${col}`));
        }
    }

    // Test 2: Probaj osnovne kolone
    console.log('\n2️⃣ Test osnovnih kolona:');
    const { data: basicData, error: basicError } = await supabase
        .from('vozaci')
        .select('id, ime, kusur, aktivan')
        .limit(3);

    if (basicError) {
        console.log('❌ Greška sa osnovnim kolonama:', basicError.message);
    } else {
        console.log('✅ Osnovne kolone rade:');
        basicData.forEach(v => {
            console.log(`  - ${v.ime} (${v.id.substring(0, 8)}...) kusur: ${v.kusur}`);
        });
    }

    // Test 3: Proveri da li postoji 'boja' kolona
    console.log('\n3️⃣ Test boja kolone:');
    const { data: bojaTest, error: bojaError } = await supabase
        .from('vozaci')
        .select('id, ime, boja')
        .limit(1);

    if (bojaError) {
        console.log('❌ Kolona "boja" ne postoji:', bojaError.message);
    } else {
        console.log('✅ Kolona "boja" postoji');
    }
}

checkTableStructure().catch(console.error);
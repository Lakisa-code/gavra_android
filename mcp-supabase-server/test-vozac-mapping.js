import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
    'https://gjtabtwudbrmfeyjiicu.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk'
);

async function testVozacMapping() {
    console.log('🔍 Test VozacMappingService simulacija...\n');

    // 1. Dobij sve vozače kao što radi VozacService.getAllVozaci() ISPRAVLJENO
    const { data: vozaci, error } = await supabase
        .from('vozaci')
        .select('id, ime, kusur, aktivan, created_at, updated_at')
        .eq('aktivan', true)
        .order('ime'); if (error) {
            console.log('❌ Greška:', error.message);
            return;
        }

    console.log('📊 Vozači iz baze (kao što ih vidi VozacService):');
    vozaci.forEach(v => {
        console.log(`  - ${v.ime} (UUID: ${v.id})`);
    });

    // 2. Simuliraj VozacMappingService._vozacNameToUuid mapiranje
    console.log('\n📝 Mapiranje što bi trebalo da VozacMappingService ima:');
    const nameToUuid = {};
    const uuidToName = {};

    vozaci.forEach(v => {
        nameToUuid[v.ime] = v.id;
        uuidToName[v.id] = v.ime;
        console.log(`  "${v.ime}" -> "${v.id}"`);
    });

    // 3. Test pretraga kao što radi AuthManager
    console.log('\n🔍 Test pretraga vozača (kako AuthManager pokušava):');

    const testNames = ['Bojan', 'Bruda', 'Bilevski', 'Svetlana', 'Mihaj Anastasija'];
    testNames.forEach(name => {
        const uuid = nameToUuid[name];
        console.log(`  "${name}" -> ${uuid ? uuid : 'NIJE PRONAĐEN'}`);
    });

    // 4. Proverava da li se SharedPreferences čita ispravno
    console.log('\n💾 Simulacija SharedPreferences problema:');
    console.log('  - current_driver možda vraća "Mihaj Anastasija" umesto "Bojan"');
    console.log('  - to objašnjava zašto se pokušava da nađe "Mihaj Anastasija" kao vozač');
    console.log('  - trebalo bi da vrati ime VOZAČA, a ne PUTNIKA');
}

testVozacMapping().catch(console.error);
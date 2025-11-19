import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://gitabtwodbrmfeyiicu.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdpdGFidHdvZGJybWZleWlpY3UiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTczMTA2MDc5NywiZXhwIjoyMDQ2NjM2Nzk3fQ.uNPwGNlP6e-Nqn8GK5PNnhN8-2vhEvZBIjKY9_0Q8GE';

const supabase = createClient(supabaseUrl, supabaseKey);

async function testVozaci() {
    try {
        console.log('🔍 Testing vozaci table...');

        // Get all vozaci
        const { data: vozaci, error } = await supabase
            .from('vozaci')
            .select('*');

        if (error) {
            console.error('❌ Error fetching vozaci:', error);
            return;
        }

        console.log('✅ Found vozaci:', vozaci.length);
        vozaci.forEach(v => {
            console.log(`  - ${v.ime} (${v.puno_ime}) - UUID: ${v.id}`);
        });

        // Check specific UUID
        const targetUuid = '0B861b65-7f26-4125-8e5d-93ce637c8d6d';
        const foundVozac = vozaci.find(v => v.id === targetUuid);

        console.log(`\n🎯 Looking for UUID: ${targetUuid}`);
        if (foundVozac) {
            console.log('✅ Found vozac:', foundVozac);
        } else {
            console.log('❌ Vozac with this UUID NOT FOUND');

            // Check similar UUIDs (case insensitive)
            const similarUuids = vozaci.filter(v =>
                v.id.toLowerCase() === targetUuid.toLowerCase()
            );

            if (similarUuids.length > 0) {
                console.log('🔍 Found similar UUID (case difference):');
                similarUuids.forEach(v => console.log(`  - ${v.ime}: ${v.id}`));
            }
        }

    } catch (error) {
        console.error('❌ Test failed:', error);
    }
}

testVozaci();
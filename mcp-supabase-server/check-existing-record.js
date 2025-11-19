import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://gitabtwodbrmfeyiicu.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdpdGFidHdvZGJybWZleWlpY3UiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTczMTA2MDc5NywiZXhwIjoyMDQ2NjM2Nzk3fQ.uNPwGNlP6e-Nqn8GK5PNnhN8-2vhEvZBIjKY9_0Q8GE';

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkExistingRecord() {
    try {
        console.log('🔍 Checking existing record with vozac_id...');

        // Find record with specific vozac_id
        const { data: records, error } = await supabase
            .from('putovanja_istorija')
            .select('id, vozac_id, napomene, created_at, putnik_ime')
            .eq('vozac_id', '0B861b65-7f26-4125-8e5d-93ce637c8d6d');

        if (error) {
            console.error('❌ Error:', error.message);
            return;
        }

        console.log('Found records:', records.length);

        if (records.length > 0) {
            records.forEach(record => {
                console.log('\n📝 Record:');
                console.log(`  ID: ${record.id}`);
                console.log(`  Vozac ID: ${record.vozac_id}`);
                console.log(`  Putnik: ${record.putnik_ime}`);
                console.log(`  Napomena: ${record.napomene}`);
                console.log(`  Created: ${record.created_at}`);
            });

            // Test VozacMappingService manually
            console.log('\n🔧 Testing vozac UUID lookup...');

            // Check all vozaci to see what UUIDs exist
            const { data: vozaci, error: vozaciError } = await supabase
                .from('vozaci')
                .select('id, ime, puno_ime')
                .limit(10);

            if (vozaciError) {
                console.error('❌ Vozaci error:', vozaciError.message);
            } else {
                console.log('Available vozaci:');
                vozaci.forEach(v => {
                    console.log(`  - ${v.ime} (${v.puno_ime}): ${v.id}`);
                });

                // Check if our UUID matches any
                const targetUuid = '0B861b65-7f26-4125-8e5d-93ce637c8d6d';
                const match = vozaci.find(v => v.id === targetUuid);

                if (match) {
                    console.log(`\n✅ Found match: ${match.ime} -> ${targetUuid}`);
                } else {
                    console.log(`\n❌ No match for UUID: ${targetUuid}`);

                    // Check for case variations
                    const caseInsensitiveMatch = vozaci.find(v =>
                        v.id.toLowerCase() === targetUuid.toLowerCase()
                    );

                    if (caseInsensitiveMatch) {
                        console.log(`🔍 Found case-insensitive match: ${caseInsensitiveMatch.ime} -> ${caseInsensitiveMatch.id}`);
                    }
                }
            }
        } else {
            console.log('❌ No records found with that vozac_id');
        }

    } catch (error) {
        console.error('❌ Error:', error.message);
    }
}

checkExistingRecord();
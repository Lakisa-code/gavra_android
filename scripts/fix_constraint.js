// Skripta za popravku CHECK constraint-a u Supabase
// Koristi direktan REST API za update vrednosti

const SUPABASE_URL = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzQzNjI5MiwiZXhwIjoyMDYzMDEyMjkyfQ.BrwnYQ6TWGB1BrmwaE0YnhMC5wMlBRdZUs1xv2dY5r4';

async function getConstraintInfo() {
    console.log('Fetching constraint info from information_schema...');

    // Probajmo da vidimo constraint info preko direktnog REST API-ja
    const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/get_constraint_info`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'apikey': SERVICE_ROLE_KEY,
            'Authorization': `Bearer ${SERVICE_ROLE_KEY}`
        },
        body: JSON.stringify({})
    });

    console.log('Status:', response.status);
    const text = await response.text();
    console.log('Response:', text);
}

async function testUpdate() {
    console.log('\n=== Test: Updating mesecni_putnici status ===');

    // Prvo dohvatimo putnika
    const getResponse = await fetch(`${SUPABASE_URL}/rest/v1/mesecni_putnici?select=id,ime,prezime,status&limit=5`, {
        headers: {
            'apikey': SERVICE_ROLE_KEY,
            'Authorization': `Bearer ${SERVICE_ROLE_KEY}`
        }
    });

    const putnici = await getResponse.json();
    console.log('Current putnici:', JSON.stringify(putnici, null, 2));

    if (putnici.length > 0) {
        const testPutnik = putnici[0];
        console.log(`\nTrying to set status='bolovanje' for ${testPutnik.ime} ${testPutnik.prezime} (id: ${testPutnik.id})...`);

        const updateResponse = await fetch(`${SUPABASE_URL}/rest/v1/mesecni_putnici?id=eq.${testPutnik.id}`, {
            method: 'PATCH',
            headers: {
                'Content-Type': 'application/json',
                'apikey': SERVICE_ROLE_KEY,
                'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
                'Prefer': 'return=representation'
            },
            body: JSON.stringify({ status: 'bolovanje' })
        });

        console.log('Update status:', updateResponse.status);
        const result = await updateResponse.text();
        console.log('Update result:', result);
    }
}

async function main() {
    console.log('=== Constraint Diagnostic Tool ===\n');
    console.log('NAPOMENA: ALTER TABLE komande ne mogu da se izvršavaju preko REST API-ja.');
    console.log('Za promenu CHECK constraint-a moraš da:');
    console.log('1. Odeš na Supabase Dashboard -> SQL Editor');
    console.log('2. Izvršiš sledeći SQL:\n');
    console.log(`
ALTER TABLE mesecni_putnici DROP CONSTRAINT IF EXISTS check_mesecni_status_valid;
ALTER TABLE mesecni_putnici ADD CONSTRAINT check_mesecni_status_valid 
CHECK (status IN ('aktivan', 'neaktivan', 'pauziran', 'radi', 'bolovanje', 'godišnji'));
    `);
    console.log('\nILI koristi alternativni pristup - ignoriši constraint i koristi napomenu polje.\n');

    await testUpdate();
}

main().catch(console.error);
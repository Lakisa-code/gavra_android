// Quick script to see actual data structure
const SUPABASE_URL = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

const headers = {
    'apikey': SUPABASE_ANON_KEY,
    'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    'Content-Type': 'application/json'
};

async function inspectData() {
    try {
        console.log('🔍 Fetching sample records to see structure...');
        
        const response = await fetch(`${SUPABASE_URL}/rest/v1/mesecni_putnici?select=*&limit=3`, {
            headers: headers
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const data = await response.json();
        console.log('\n📊 SAMPLE DATA STRUCTURE:');
        console.log('='.repeat(60));
        
        data.forEach((record, index) => {
            console.log(`\n🔍 RECORD ${index + 1}:`);
            console.log(JSON.stringify(record, null, 2));
        });
        
    } catch (error) {
        console.error('❌ Error:', error);
    }
}

inspectData();
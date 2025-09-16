// Script to check what years we have in the database
const SUPABASE_URL = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

const headers = {
    'apikey': SUPABASE_ANON_KEY,
    'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    'Content-Type': 'application/json'
};

async function analyzeYearData() {
    console.log('🔍 ANALYZING YEAR DATA IN DATABASE');
    console.log('='.repeat(60));
    
    try {
        // Check mesecni_putnici table
        console.log('\n📊 MESECNI_PUTNICI TABLE:');
        const mesecniResponse = await fetch(`${SUPABASE_URL}/rest/v1/mesecni_putnici?select=*`, {
            headers: headers
        });
        const mesecni = await mesecniResponse.json();
        
        const mesecniYears = new Set();
        const mesecniPaymentYears = new Set();
        
        mesecni.forEach(m => {
            if (m.created_at) {
                const year = new Date(m.created_at).getFullYear();
                mesecniYears.add(year);
            }
            if (m.vreme_placanja) {
                const year = new Date(m.vreme_placanja).getFullYear();
                mesecniPaymentYears.add(year);
            }
        });
        
        console.log(`Total records: ${mesecni.length}`);
        console.log(`Years found (created_at): ${Array.from(mesecniYears).sort()}`);
        console.log(`Years found (vreme_placanja): ${Array.from(mesecniPaymentYears).sort()}`);
        
        // Show detailed breakdown by year for payments
        console.log('\n💰 PAYMENT BREAKDOWN BY YEAR:');
        const yearBreakdown = {};
        
        mesecni.forEach(m => {
            if (m.vreme_placanja && m.cena && m.cena > 0) {
                const year = new Date(m.vreme_placanja).getFullYear();
                if (!yearBreakdown[year]) yearBreakdown[year] = { count: 0, total: 0 };
                yearBreakdown[year].count++;
                yearBreakdown[year].total += parseFloat(m.cena);
            }
        });
        
        Object.entries(yearBreakdown).sort().forEach(([year, data]) => {
            console.log(`${year}: ${data.count} payments = ${data.total.toFixed(0)} RSD`);
        });
        
        console.log('\n🔍 CURRENT ISSUE:');
        console.log('StatistikaScreen "godina" filter only uses current year (2025)');
        console.log('But we might have data from other years that should be accessible');
        
        return yearBreakdown;
        
    } catch (error) {
        console.error('❌ Error:', error);
        return null;
    }
}

analyzeYearData().catch(console.error);
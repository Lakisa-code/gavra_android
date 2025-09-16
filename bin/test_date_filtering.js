// Quick test to see which passengers would be excluded by date filtering
const SUPABASE_URL = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

const headers = {
    'apikey': SUPABASE_ANON_KEY,
    'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    'Content-Type': 'application/json'
};

async function testDateFiltering() {
    console.log('🔍 TESTING DATE FILTERING IMPACT ON MONTHLY PASSENGERS');
    console.log('='.repeat(70));
    
    try {
        const response = await fetch(`${SUPABASE_URL}/rest/v1/mesecni_putnici?select=*`, {
            headers: headers
        });
        
        const data = await response.json();
        
        // September filter (like StatistikaScreen uses)
        const septemberStart = new Date('2025-09-01');
        const septemberEnd = new Date('2025-09-30T23:59:59');
        
        let totalAmount = 0;
        let septemberFilteredAmount = 0;
        let augustPaidCount = 0;
        let septemberPaidCount = 0;
        
        console.log('\n📊 ANALYZING PAYMENT DATES VS SEPTEMBER FILTER:');
        console.log('='.repeat(70));
        console.log('September filter: 2025-09-01 to 2025-09-30');
        console.log('='.repeat(70));
        
        data.forEach(record => {
            const cena = parseFloat(record.cena) || 0;
            const vremePlacanja = new Date(record.vreme_placanja);
            const placeniMesec = record.placeni_mesec;
            const obrisan = record.obrisan;
            
            if (record.vreme_placanja && !obrisan) {
                totalAmount += cena;
                
                // Check if payment date falls within September filter
                if (vremePlacanja >= septemberStart && vremePlacanja <= septemberEnd) {
                    septemberFilteredAmount += cena;
                    console.log(`✅ INCLUDED | ${record.putnik_ime.padEnd(20)} | ${cena.toString().padStart(6)} RSD | Paid: ${vremePlacanja.toISOString().split('T')[0]} | Month: ${placeniMesec}/2025`);
                } else {
                    console.log(`❌ EXCLUDED | ${record.putnik_ime.padEnd(20)} | ${cena.toString().padStart(6)} RSD | Paid: ${vremePlacanja.toISOString().split('T')[0]} | Month: ${placeniMesec}/2025`);
                }
                
                if (placeniMesec === 8) {
                    augustPaidCount++;
                } else if (placeniMesec === 9) {
                    septemberPaidCount++;
                }
            }
        });
        
        console.log('\n' + '='.repeat(70));
        console.log('📈 FILTERING RESULTS SUMMARY:');
        console.log('='.repeat(70));
        console.log(`Total amount (all paid):           ${totalAmount.toFixed(0)} RSD`);
        console.log(`September filtered amount:         ${septemberFilteredAmount.toFixed(0)} RSD`);
        console.log(`Lost amount due to filtering:      ${(totalAmount - septemberFilteredAmount).toFixed(0)} RSD`);
        console.log(`Passengers paid in August:         ${augustPaidCount}`);
        console.log(`Passengers paid in September:      ${septemberPaidCount}`);
        
        console.log('\n🎯 CONCLUSION:');
        if (totalAmount !== septemberFilteredAmount) {
            console.log('❌ DATE FILTERING IS CAUSING DATA LOSS!');
            console.log('💡 Monthly passengers should be filtered by active month, not payment date');
        } else {
            console.log('✅ Date filtering is working correctly');
        }
        
        return {
            totalAmount,
            septemberFilteredAmount,
            lostAmount: totalAmount - septemberFilteredAmount,
            augustPaidCount,
            septemberPaidCount
        };
        
    } catch (error) {
        console.error('❌ Error:', error);
        return null;
    }
}

testDateFiltering().catch(console.error);
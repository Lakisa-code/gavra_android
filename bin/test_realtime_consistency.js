// Test script to check if real-time calculations match Supabase data
const SUPABASE_URL = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

const headers = {
    'apikey': SUPABASE_ANON_KEY,
    'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    'Content-Type': 'application/json'
};

async function testRealTimeConsistency() {
    console.log('🔍 TESTING REAL-TIME CONSISTENCY WITH SUPABASE DATA');
    console.log('='.repeat(60));
    
    try {
        // 1. Get direct Supabase data
        const response = await fetch(`${SUPABASE_URL}/rest/v1/mesecni_putnici?select=*`, {
            headers: headers
        });
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const supabaseData = await response.json();
        
        // 2. Calculate totals by vozac (driver) like the app does
        const vozacTotals = {};
        let grandTotal = 0;
        let paidCount = 0;
        
        console.log('\n📊 ANALYZING MESECNI_PUTNICI DATA BY VOZAC:');
        console.log('='.repeat(50));
        
        supabaseData.forEach(record => {
            const cena = parseFloat(record.cena) || 0;
            const vozac = record.naplata_vozac || 'Unknown';
            const vremePlacanja = record.vreme_placanja;
            const status = record.status;
            const obrisan = record.obrisan;
            
            // App logic: only count if has payment time and not deleted
            if (vremePlacanja && !obrisan && status !== 'obrisan') {
                if (!vozacTotals[vozac]) {
                    vozacTotals[vozac] = { count: 0, total: 0 };
                }
                
                vozacTotals[vozac].count++;
                vozacTotals[vozac].total += cena;
                grandTotal += cena;
                paidCount++;
                
                console.log(`✅ ${record.putnik_ime.padEnd(15)} | ${vozac.padEnd(10)} | ${cena.toFixed(0).padStart(6)} RSD | ${record.placeni_mesec}/${record.placena_godina}`);
            } else {
                console.log(`❌ ${record.putnik_ime.padEnd(15)} | SKIPPED | Status: ${status}, Obrisan: ${obrisan}, Payment: ${vremePlacanja ? 'YES' : 'NO'}`);
            }
        });
        
        console.log('\n' + '='.repeat(60));
        console.log('📈 SUMMARY BY VOZAC (matching app logic):');
        console.log('='.repeat(60));
        
        Object.entries(vozacTotals)
            .sort((a, b) => b[1].total - a[1].total)
            .forEach(([vozac, data]) => {
                console.log(`${vozac.padEnd(15)} | ${data.count.toString().padStart(2)} passengers | ${data.total.toFixed(0).padStart(8)} RSD`);
            });
        
        console.log('='.repeat(60));
        console.log(`🎯 TOTAL MATCHING APP LOGIC: ${grandTotal.toFixed(0)} RSD`);
        console.log(`👥 Total paid passengers: ${paidCount}/${supabaseData.length}`);
        console.log(`📅 Current month: September 2025`);
        console.log('='.repeat(60));
        
        // 3. Check for consistency issues
        const expectedTotal = 526700; // From our previous analysis
        const difference = Math.abs(grandTotal - expectedTotal);
        
        console.log('\n🔍 CONSISTENCY CHECK:');
        console.log('='.repeat(40));
        console.log(`Expected (from previous analysis): ${expectedTotal.toFixed(0)} RSD`);
        console.log(`Calculated (with app logic):       ${grandTotal.toFixed(0)} RSD`);
        console.log(`Difference:                        ${difference.toFixed(0)} RSD`);
        
        if (difference === 0) {
            console.log('✅ PERFECT MATCH - Real-time should show same amount!');
        } else if (difference < 100) {
            console.log('⚠️  Small difference - likely rounding or filtering');
        } else {
            console.log('❌ SIGNIFICANT DIFFERENCE - investigate filtering logic');
        }
        
        return { grandTotal, vozacTotals, paidCount, difference };
        
    } catch (error) {
        console.error('❌ Error in consistency test:', error);
        return null;
    }
}

// Run the test
testRealTimeConsistency().catch(console.error);
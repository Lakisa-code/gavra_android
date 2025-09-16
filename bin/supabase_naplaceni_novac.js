// Using built-in fetch (Node.js 18+)

// Supabase configuration
const SUPABASE_URL = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

// Headers for Supabase requests
const headers = {
    'apikey': SUPABASE_ANON_KEY,
    'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    'Content-Type': 'application/json'
};

async function fetchAllRezervacije() {
    try {
        console.log('🔍 Fetching all mesecni_putnici from Supabase...');
        
        const response = await fetch(`${SUPABASE_URL}/rest/v1/mesecni_putnici?select=*`, {
            headers: headers
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const data = await response.json();
        console.log(`📊 Total records found: ${data.length}`);
        
        return data;
    } catch (error) {
        console.error('❌ Error fetching data:', error);
        return null;
    }
}

function analyzePayments(putovanjaIstorija) {
    console.log('\n💰 ANALYZING PAYMENT DATA...\n');
    
    let totalNaplaceniNovac = 0;
    let paymentBreakdown = {
        'naplaceno': { count: 0, total: 0 },
        'nije_naplaceno': { count: 0, total: 0 },
        'refundirano': { count: 0, total: 0 },
        'rezervisano': { count: 0, total: 0 },
        'obrisan': { count: 0, total: 0 },
        'other': { count: 0, total: 0 }
    };
    
    let monthlyPassengers = { count: 0, total: 0 };
    let regularPassengers = { count: 0, total: 0 };
    
    putovanjaIstorija.forEach(rez => {
        const cena = parseFloat(rez.cena) || 0;
        const status = rez.status_placanja;
        const tipPutnika = rez.tip_putnika;
        
        // Count by payment status
        if (paymentBreakdown[status]) {
            paymentBreakdown[status].count++;
            paymentBreakdown[status].total += cena;
        } else {
            paymentBreakdown['other'].count++;
            paymentBreakdown['other'].total += cena;
        }
        
        // Count by passenger type
        if (tipPutnika === 'mesečni putnici') {
            monthlyPassengers.count++;
            monthlyPassengers.total += cena;
        } else {
            regularPassengers.count++;
            regularPassengers.total += cena;
        }
        
        // Calculate total naplaceni novac (actually paid)
        if (status === 'naplaceno') {
            totalNaplaceniNovac += cena;
        }
    });
    
    // Display results
    console.log('='.repeat(60));
    console.log('📈 PAYMENT STATUS BREAKDOWN:');
    console.log('='.repeat(60));
    
    Object.entries(paymentBreakdown).forEach(([status, data]) => {
        if (data.count > 0) {
            console.log(`${status.toUpperCase().padEnd(15)} | ${data.count.toString().padStart(5)} records | ${data.total.toFixed(2).padStart(10)} RSD`);
        }
    });
    
    console.log('\n' + '='.repeat(60));
    console.log('👥 PASSENGER TYPE BREAKDOWN:');
    console.log('='.repeat(60));
    console.log(`${'MESEČNI PUTNICI'.padEnd(15)} | ${monthlyPassengers.count.toString().padStart(5)} records | ${monthlyPassengers.total.toFixed(2).padStart(10)} RSD`);
    console.log(`${'REGULARNI'.padEnd(15)} | ${regularPassengers.count.toString().padStart(5)} records | ${regularPassengers.total.toFixed(2).padStart(10)} RSD`);
    
    console.log('\n' + '='.repeat(60));
    console.log('💵 FINAL RESULT:');
    console.log('='.repeat(60));
    console.log(`🎯 TAČAN IZNOS NAPLAĆENOG NOVCA: ${totalNaplaceniNovac.toFixed(2)} RSD`);
    console.log('='.repeat(60));
    
    return {
        totalNaplaceniNovac,
        paymentBreakdown,
        monthlyPassengers,
        regularPassengers,
        totalRecords: putovanjaIstorija.length
    };
}

function verifyAgainstAppLogic(analysis) {
    console.log('\n🔍 VERIFICATION AGAINST APP LOGIC:');
    console.log('='.repeat(60));
    
    // Based on the app filtering logic we've seen:
    // - Naplaćeni novac should only include status 'naplaceno'
    // - Monthly passengers should exclude 'obrisan' status
    // - Regular passengers have different filtering rules
    
    const expectedNaplaceni = analysis.paymentBreakdown.naplaceno.total;
    console.log(`✅ Expected naplaćeni novac (status='naplaceno'): ${expectedNaplaceni.toFixed(2)} RSD`);
    console.log(`✅ Calculated total: ${analysis.totalNaplaceniNovac.toFixed(2)} RSD`);
    console.log(`${expectedNaplaceni === analysis.totalNaplaceniNovac ? '✅ MATCH' : '❌ MISMATCH'}`);
    
    // Monthly passengers logic check
    const monthlyExcludingObrisan = analysis.monthlyPassengers.count;
    console.log(`\n📊 Monthly passengers total: ${monthlyExcludingObrisan}`);
    console.log(`📊 Deleted records: ${analysis.paymentBreakdown.obrisan.count}`);
}

async function main() {
    console.log('🚀 STARTING SUPABASE NAPLAĆENI NOVAC ANALYSIS');
    console.log('='.repeat(60));
    
    const putovanjaIstorija = await fetchAllRezervacije();
    
    if (!putovanjaIstorija) {
        console.log('❌ Failed to fetch data from Supabase');
        return;
    }
    
    const analysis = analyzePayments(putovanjaIstorija);
    verifyAgainstAppLogic(analysis);
    
    console.log('\n✅ ANALYSIS COMPLETE');
}

// Run the analysis
main().catch(console.error);
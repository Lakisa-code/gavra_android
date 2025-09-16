// Debug script to test how the app grouping logic affects totals
const SUPABASE_URL = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

const headers = {
    'apikey': SUPABASE_ANON_KEY,
    'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    'Content-Type': 'application/json'
};

async function testGroupingLogic() {
    console.log('🔍 TESTING APP GROUPING LOGIC SIMULATION');
    console.log('='.repeat(60));
    
    try {
        const response = await fetch(`${SUPABASE_URL}/rest/v1/mesecni_putnici?select=*`, {
            headers: headers
        });
        
        const data = await response.json();
        
        // Simulate app logic: Group monthly passengers by name
        const mesecniPutniciGrupisani = {};
        let totalBeforeGrouping = 0;
        let totalAfterGrouping = 0;
        let validPutnici = 0;
        let duplicatesFound = 0;
        
        console.log('\n📊 SIMULATING APP GROUPING LOGIC:');
        console.log('='.repeat(60));
        
        // September date range (like StatistikaScreen)
        const septemberStart = new Date('2025-09-01');
        const septemberEnd = new Date('2025-09-30T23:59:59');
        
        data.forEach(record => {
            const cena = parseFloat(record.cena) || 0;
            const vremePlacanja = new Date(record.vreme_placanja);
            const naplatioVozac = record.naplata_vozac;
            const ime = record.putnik_ime;
            const obrisan = record.obrisan;
            
            // App validation logic simulation
            const imaIznos = cena > 0;
            const imaVozaca = naplatioVozac && naplatioVozac.length > 0;
            const imaVremePlacanja = record.vreme_placanja;
            const isValidPayment = imaIznos && imaVozaca && imaVremePlacanja && !obrisan;
            const isInTimeRange = vremePlacanja >= septemberStart && vremePlacanja <= septemberEnd;
            
            if (isValidPayment) {
                totalBeforeGrouping += cena;
                validPutnici++;
                
                if (isInTimeRange) {
                    // App grouping logic: only first valid passenger per name
                    if (!mesecniPutniciGrupisani[ime]) {
                        mesecniPutniciGrupisani[ime] = {
                            cena: cena,
                            vozac: naplatioVozac,
                            vreme: record.vreme_placanja
                        };
                        totalAfterGrouping += cena;
                        console.log(`✅ GROUPED | ${ime.padEnd(20)} | ${cena.toString().padStart(6)} RSD | ${naplatioVozac.padEnd(8)} | First occurrence`);
                    } else {
                        duplicatesFound++;
                        console.log(`🔄 DUPLICATE | ${ime.padEnd(20)} | ${cena.toString().padStart(6)} RSD | ${naplatioVozac.padEnd(8)} | Skipped (duplicate name)`);
                    }
                } else {
                    console.log(`❌ OUT_OF_RANGE | ${ime.padEnd(20)} | ${cena.toString().padStart(6)} RSD | Payment: ${record.vreme_placanja.split('T')[0]}`);
                }
            } else {
                console.log(`❌ INVALID | ${ime.padEnd(20)} | ${cena.toString().padStart(6)} RSD | Missing: ${!imaIznos ? 'amount' : !imaVozaca ? 'driver' : !imaVremePlacanja ? 'payment_time' : 'deleted'}`);
            }
        });
        
        console.log('\n' + '='.repeat(60));
        console.log('📈 GROUPING SIMULATION RESULTS:');
        console.log('='.repeat(60));
        console.log(`Total records:                  ${data.length}`);
        console.log(`Valid records (before grouping): ${validPutnici} = ${totalBeforeGrouping.toFixed(0)} RSD`);
        console.log(`After grouping by name:         ${Object.keys(mesecniPutniciGrupisani).length} = ${totalAfterGrouping.toFixed(0)} RSD`);
        console.log(`Duplicates found:               ${duplicatesFound}`);
        console.log(`Lost due to grouping:           ${(totalBeforeGrouping - totalAfterGrouping).toFixed(0)} RSD`);
        
        console.log('\n🎯 VOZAC BREAKDOWN:');
        const vozacBreakdown = {};
        Object.values(mesecniPutniciGrupisani).forEach(putnik => {
            if (!vozacBreakdown[putnik.vozac]) {
                vozacBreakdown[putnik.vozac] = { count: 0, total: 0 };
            }
            vozacBreakdown[putnik.vozac].count++;
            vozacBreakdown[putnik.vozac].total += putnik.cena;
        });
        
        Object.entries(vozacBreakdown).forEach(([vozac, data]) => {
            console.log(`${vozac.padEnd(15)} | ${data.count.toString().padStart(2)} passengers | ${data.total.toFixed(0).padStart(8)} RSD`);
        });
        
        console.log('\n💡 EXPECTED IN STATISTIKA SCREEN:', totalAfterGrouping.toFixed(0), 'RSD');
        
        return {
            totalBeforeGrouping,
            totalAfterGrouping,
            duplicatesFound,
            uniquePassengers: Object.keys(mesecniPutniciGrupisani).length
        };
        
    } catch (error) {
        console.error('❌ Error:', error);
        return null;
    }
}

testGroupingLogic().catch(console.error);
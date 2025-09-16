// Script to debug year filtering inconsistency in StatistikaScreen
const SUPABASE_URL = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

const headers = {
    'apikey': SUPABASE_ANON_KEY,
    'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    'Content-Type': 'application/json'
};

async function debugYearFiltering() {
    console.log('🔍 DEBUGGING YEAR FILTERING INCONSISTENCY');
    console.log('='.repeat(60));
    
    try {
        // Get all mesecni_putnici data
        const response = await fetch(`${SUPABASE_URL}/rest/v1/mesecni_putnici?select=*`, {
            headers: headers
        });
        const putnici = await response.json();
        
        console.log(`📊 Total records: ${putnici.length}`);
        
        // Test different date ranges like StatistikaScreen would
        const now = new Date();
        
        // 1. Week filter (like "Pon-Pet")
        const monday = new Date(now);
        monday.setDate(now.getDate() - (now.getDay() - 1));
        monday.setHours(0, 0, 0, 0);
        
        const saturday = new Date(monday);
        saturday.setDate(monday.getDate() - 2); // Subota pre ponedeljka
        
        const friday = new Date(monday);
        friday.setDate(monday.getDate() + 4);
        friday.setHours(23, 59, 59, 999);
        
        // 2. Month filter (like "Mesec")
        const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
        const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59);
        
        // 3. Year filter (like "Godina") - should be for SELECTED year
        const yearStart = new Date(2025, 0, 1); // January 1, 2025
        const yearEnd = new Date(2025, 11, 31, 23, 59, 59); // December 31, 2025
        
        console.log('\n📅 DATE RANGES:');
        console.log(`Week (Pon-Pet): ${saturday.toISOString().split('T')[0]} to ${friday.toISOString().split('T')[0]}`);
        console.log(`Month (Mesec): ${monthStart.toISOString().split('T')[0]} to ${monthEnd.toISOString().split('T')[0]}`);
        console.log(`Year (Godina): ${yearStart.toISOString().split('T')[0]} to ${yearEnd.toISOString().split('T')[0]}`);
        
        // Function to check if payment is in date range
        function isInDateRange(vremePlacanja, from, to) {
            if (!vremePlacanja) return false;
            const paymentDate = new Date(vremePlacanja);
            return paymentDate >= from && paymentDate <= to;
        }
        
        // Filter and calculate for each period
        const periods = [
            { name: 'Week (Pon-Pet)', from: saturday, to: friday },
            { name: 'Month (Mesec)', from: monthStart, to: monthEnd },
            { name: 'Year (Godina)', from: yearStart, to: yearEnd }
        ];
        
        console.log('\n💰 PAYMENT ANALYSIS:');
        
        periods.forEach(period => {
            const validPayments = putnici.filter(p => 
                p.vreme_placanja && 
                p.cena && 
                p.cena > 0 && 
                p.naplatio_vozac &&
                isInDateRange(p.vreme_placanja, period.from, period.to)
            );
            
            const totalAmount = validPayments.reduce((sum, p) => sum + parseFloat(p.cena), 0);
            const byDriver = {};
            
            validPayments.forEach(p => {
                const driver = p.naplatio_vozac;
                if (!byDriver[driver]) byDriver[driver] = { count: 0, total: 0 };
                byDriver[driver].count++;
                byDriver[driver].total += parseFloat(p.cena);
            });
            
            console.log(`\n📊 ${period.name}:`);
            console.log(`  Valid payments: ${validPayments.length}`);
            console.log(`  Total amount: ${totalAmount.toFixed(0)} RSD`);
            console.log('  By driver:');
            Object.entries(byDriver).forEach(([driver, data]) => {
                console.log(`    ${driver}: ${data.count} payments = ${data.total.toFixed(0)} RSD`);
            });
            
            if (validPayments.length > 0) {
                console.log('  Sample payments:');
                validPayments.slice(0, 3).forEach(p => {
                    console.log(`    ${p.ime}: ${p.cena} RSD on ${p.vreme_placanja?.split('T')[0]} by ${p.naplatio_vozac}`);
                });
            }
        });
        
        // Check specific dates for debugging
        console.log('\n🔍 DETAILED DATE ANALYSIS:');
        
        const allPaymentDates = putnici
            .filter(p => p.vreme_placanja && p.cena && p.cena > 0)
            .map(p => ({
                name: p.ime,
                date: p.vreme_placanja,
                amount: p.cena,
                driver: p.naplatio_vozac
            }))
            .sort((a, b) => new Date(a.date) - new Date(b.date));
            
        console.log(`Total payments with dates: ${allPaymentDates.length}`);
        console.log('Date range of payments:');
        if (allPaymentDates.length > 0) {
            console.log(`  Earliest: ${allPaymentDates[0].date?.split('T')[0]}`);
            console.log(`  Latest: ${allPaymentDates[allPaymentDates.length - 1].date?.split('T')[0]}`);
        }
        
        // Check for month boundaries
        const septemberPayments = allPaymentDates.filter(p => p.date?.includes('2025-09'));
        console.log(`\nSeptember 2025 payments: ${septemberPayments.length}`);
        septemberPayments.slice(0, 5).forEach(p => {
            console.log(`  ${p.name}: ${p.amount} RSD on ${p.date?.split('T')[0]} by ${p.driver}`);
        });
        
        console.log('\n🚨 POTENTIAL ISSUES:');
        console.log('1. Check if StatistikaScreen _calculatePeriod() uses correct dates');
        console.log('2. Verify _jeUVremenskomOpsegu() function logic');
        console.log('3. Ensure year dropdown selection (_selectedYear) is working');
        console.log('4. Check if UI is correctly passing year parameter to service');
        
        return allPaymentDates;
        
    } catch (error) {
        console.error('❌ Error:', error);
        return null;
    }
}

debugYearFiltering().catch(console.error);
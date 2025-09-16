// Comprehensive analysis of ALL tables in Supabase
const SUPABASE_URL = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

const headers = {
    'apikey': SUPABASE_ANON_KEY,
    'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    'Content-Type': 'application/json'
};

// List of tables we know exist from the code
const KNOWN_TABLES = [
    'putovanja_istorija',
    'mesecni_putnici', 
    'gps_lokacije'
];

async function analyzeTable(tableName) {
    try {
        console.log(`\n🔍 ANALYZING TABLE: ${tableName.toUpperCase()}`);
        console.log('='.repeat(50));
        
        const response = await fetch(`${SUPABASE_URL}/rest/v1/${tableName}?select=*`, {
            headers: headers
        });

        if (!response.ok) {
            console.log(`❌ ${tableName}: HTTP ${response.status} - Table not accessible`);
            return { tableName, count: 0, total: 0, error: `HTTP ${response.status}` };
        }

        const data = await response.json();
        console.log(`📊 ${tableName}: ${data.length} records found`);
        
        if (data.length === 0) {
            return { tableName, count: 0, total: 0 };
        }

        // Show sample record structure
        console.log(`\n📋 Sample record structure:`);
        const sampleKeys = Object.keys(data[0]).filter(key => 
            key.includes('cena') || 
            key.includes('novac') || 
            key.includes('plac') || 
            key.includes('status') ||
            key.includes('ukupno') ||
            key.includes('iznos')
        );
        console.log(`Payment-related columns: ${sampleKeys.join(', ') || 'None found'}`);
        
        // Calculate totals if cena column exists
        let total = 0;
        let paidCount = 0;
        let statusBreakdown = {};
        
        data.forEach(record => {
            // Check for price/amount columns
            const cena = parseFloat(record.cena) || 0;
            total += cena;
            
            // Check payment status indicators
            if (record.vreme_placanja || record.status_placanja === 'naplaceno' || record.status === 'naplaceno') {
                paidCount++;
            }
            
            // Status breakdown
            const status = record.status_placanja || record.status || 'unknown';
            statusBreakdown[status] = (statusBreakdown[status] || 0) + 1;
        });
        
        console.log(`💰 Total amount: ${total.toFixed(2)} RSD`);
        console.log(`✅ Paid records: ${paidCount}/${data.length}`);
        console.log(`📈 Status breakdown:`, statusBreakdown);
        
        return { 
            tableName, 
            count: data.length, 
            total, 
            paidCount, 
            statusBreakdown 
        };
        
    } catch (error) {
        console.log(`❌ ${tableName}: Error - ${error.message}`);
        return { tableName, count: 0, total: 0, error: error.message };
    }
}

async function comprehensiveAnalysis() {
    console.log('🚀 COMPREHENSIVE SUPABASE PAYMENT ANALYSIS');
    console.log('='.repeat(60));
    
    const results = [];
    
    // Check all known tables
    for (const table of KNOWN_TABLES) {
        const result = await analyzeTable(table);
        results.push(result);
        await new Promise(resolve => setTimeout(resolve, 500)); // Small delay
    }
    
    // Also try some common table names that might exist
    const POTENTIAL_TABLES = [
        'putnici',
        'rezervacije', 
        'placanja',
        'karte',
        'transakcije',
        'daily_passengers',
        'regular_passengers'
    ];
    
    console.log('\n🔍 CHECKING POTENTIAL ADDITIONAL TABLES...');
    for (const table of POTENTIAL_TABLES) {
        const result = await analyzeTable(table);
        if (!result.error) {
            results.push(result);
        }
        await new Promise(resolve => setTimeout(resolve, 300));
    }
    
    // Summary
    console.log('\n' + '='.repeat(60));
    console.log('📊 COMPREHENSIVE SUMMARY');
    console.log('='.repeat(60));
    
    let grandTotal = 0;
    let totalRecords = 0;
    
    results.forEach(result => {
        if (!result.error && result.total > 0) {
            console.log(`${result.tableName.toUpperCase().padEnd(20)} | ${result.count.toString().padStart(4)} records | ${result.total.toFixed(2).padStart(12)} RSD`);
            grandTotal += result.total;
            totalRecords += result.count;
        }
    });
    
    console.log('='.repeat(60));
    console.log(`🎯 UKUPAN NAPLAĆENI NOVAC: ${grandTotal.toFixed(2)} RSD`);
    console.log(`📋 Ukupno zapisa: ${totalRecords}`);
    console.log('='.repeat(60));
    
    return { results, grandTotal, totalRecords };
}

// Run comprehensive analysis
comprehensiveAnalysis().catch(console.error);
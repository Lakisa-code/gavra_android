const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzA2NDk5MzMsImV4cCI6MjA0NjIyNTkzM30.Ld-0pK4nCYCnrfLqt5HBJCkEI-LUUMPxj6TQgNepZiA';

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkYearFilter() {
  console.log('🔍 CHECKING YEAR FILTER ISSUE...\n');
  
  // Get current year parameters (as used by _calculatePeriod)
  const now = new Date();
  const currentYear = now.getFullYear();
  const yearFrom = new Date(currentYear, 0, 1); // January 1st
  const yearTo = new Date(currentYear, 11, 31, 23, 59, 59); // December 31st
  
  console.log('📅 Year filter parameters:');
  console.log(`From: ${yearFrom.toISOString()}`);
  console.log(`To: ${yearTo.toISOString()}`);
  console.log(`Current year: ${currentYear}\n`);
  
  // Check mesecni_putnici data
  console.log('🎫 MESEČNI PUTNICI DATA:');
  const { data: mesecni, error: mesecniError } = await supabase
    .from('mesecni_putnici')
    .select('ime, vreme_placanja, iznos_placanja, naplaćio_vozac')
    .order('vreme_placanja');
    
  if (mesecniError) {
    console.error('❌ Error:', mesecniError);
    return;
  }
  
  if (!mesecni || mesecni.length === 0) {
    console.log('❌ No mesecni_putnici data found');
    return;
  }
  
  console.log(`Total mesecni entries: ${mesecni.length}`);
  
  // Group by year
  const yearCounts = {};
  mesecni.forEach(entry => {
    if (entry.vreme_placanja) {
      const entryDate = new Date(entry.vreme_placanja);
      const year = entryDate.getFullYear();
      if (!yearCounts[year]) yearCounts[year] = [];
      yearCounts[year].push(entry);
    }
  });
  
  console.log('\n📊 Data by year:');
  Object.keys(yearCounts).sort().forEach(year => {
    console.log(`  ${year}: ${yearCounts[year].length} entries`);
  });
  
  // Check current year data specifically
  const currentYearData = yearCounts[currentYear] || [];
  console.log(`\n🎯 Current year (${currentYear}) detailed check:`);
  console.log(`Entries found: ${currentYearData.length}`);
  
  if (currentYearData.length > 0) {
    console.log('\n📋 Current year entries:');
    currentYearData.forEach((entry, index) => {
      const date = new Date(entry.vreme_placanja);
      console.log(`${index + 1}. ${entry.ime}: ${entry.iznos_placanja} RSD (${date.toLocaleDateString()}) - vozač: ${entry.naplaćio_vozac}`);
    });
    
    // Check if dates fall within year filter
    console.log('\n🔍 Date range check:');
    let validCount = 0;
    currentYearData.forEach(entry => {
      const entryDate = new Date(entry.vreme_placanja);
      const isValid = entryDate >= yearFrom && entryDate <= yearTo;
      if (isValid) validCount++;
      console.log(`${entry.ime}: ${entryDate.toISOString()} - ${isValid ? '✅ VALID' : '❌ INVALID'}`);
    });
    
    console.log(`\n📊 Summary: ${validCount}/${currentYearData.length} entries are within year filter range`);
    
    // Calculate total for current year
    const totalCurrentYear = currentYearData.reduce((sum, entry) => {
      return sum + (entry.iznos_placanja || 0);
    }, 0);
    
    console.log(`💰 Total for ${currentYear}: ${totalCurrentYear} RSD`);
  } else {
    console.log('❌ No data found for current year');
    
    // Show what years we do have data for
    if (Object.keys(yearCounts).length > 0) {
      console.log('\n📅 Available years:');
      Object.keys(yearCounts).sort().forEach(year => {
        const firstEntry = yearCounts[year][0];
        const lastEntry = yearCounts[year][yearCounts[year].length - 1];
        console.log(`  ${year}: ${yearCounts[year].length} entries`);
        console.log(`    First: ${new Date(firstEntry.vreme_placanja).toLocaleDateString()}`);
        console.log(`    Last: ${new Date(lastEntry.vreme_placanja).toLocaleDateString()}`);
      });
    }
  }
  
  // Check putnici table too
  console.log('\n🎟️ PUTNICI DATA:');
  const { data: putnici, error: putniciError } = await supabase
    .from('putnici')
    .select('ime, vreme_placanja, iznos_placanja, naplaćio_vozac')
    .order('vreme_placanja');
    
  if (putniciError) {
    console.error('❌ Error:', putniciError);
    return;
  }
  
  if (putnici && putnici.length > 0) {
    const putniciYearCounts = {};
    putnici.forEach(entry => {
      if (entry.vreme_placanja) {
        const year = new Date(entry.vreme_placanja).getFullYear();
        putniciYearCounts[year] = (putniciYearCounts[year] || 0) + 1;
      }
    });
    
    console.log(`Total putnici entries: ${putnici.length}`);
    console.log('Putnici by year:');
    Object.keys(putniciYearCounts).sort().forEach(year => {
      console.log(`  ${year}: ${putniciYearCounts[year]} entries`);
    });
  } else {
    console.log('No putnici data found');
  }
}

checkYearFilter().catch(console.error);
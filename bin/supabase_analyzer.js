// Node.js script za direktan pristup Supabase bazi
const https = require('https');

const SUPABASE_URL = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

function makeRequest(path, filters = '') {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'gjtabtwudbrmfeyjiicu.supabase.co',
      port: 443,
      path: `/rest/v1/${path}${filters}`,
      method: 'GET',
      headers: {
        'apikey': SUPABASE_KEY,
        'Authorization': `Bearer ${SUPABASE_KEY}`,
        'Content-Type': 'application/json'
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          console.log(`   🔍 Raw response:`, typeof parsed, Array.isArray(parsed) ? `Array[${parsed.length}]` : 'Object');
          resolve(parsed);
        } catch (e) {
          console.log(`   ❌ Parse error:`, e.message);
          console.log(`   📄 Raw data:`, data.substring(0, 200));
          reject(e);
        }
      });
    });

    req.on('error', (e) => {
      reject(e);
    });

    req.end();
  });
}

async function analyzePayments() {
  console.log('🔍 === ANALIZA NAPLAĆENOG NOVCA U SUPABASE ===');
  console.log('📅 Datum:', new Date().toLocaleDateString('sr-RS'));
  console.log('');

  try {
    const today = new Date();
    const todayStart = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    const todayEnd = new Date(today.getFullYear(), today.getMonth(), today.getDate(), 23, 59, 59);
    
    const startISO = todayStart.toISOString();
    const endISO = todayEnd.toISOString();

    console.log(`🕐 Period: ${todayStart.toLocaleString('sr-RS')} - ${todayEnd.toLocaleString('sr-RS')}`);
    console.log('');

    // 1. DNEVNI PUTNICI
    console.log('📊 1. DNEVNI PUTNICI (tabela: putnici)');
    const dnevniFilters = `?select=naplatioVozac,iznosPlacanja,vremePlacanja,ime&vremePlacanja=gte.${startISO}&vremePlacanja=lte.${endISO}&mesecnaKarta=neq.true&jeOtkazan=neq.true`;
    
    const dnevniPutnici = await makeRequest('putnici', dnevniFilters);
    console.log(`   Broj zapisa: ${dnevniPutnici.length}`);

    let ukupnoDnevni = 0;
    let pazarDnevni = {};
    let placeniDnevni = 0;

    dnevniPutnici.forEach(putnik => {
      const iznos = parseFloat(putnik.iznosPlacanja || 0);
      if (iznos > 0) {
        const vozac = putnik.naplatioVozac || 'Nepoznat';
        ukupnoDnevni += iznos;
        pazarDnevni[vozac] = (pazarDnevni[vozac] || 0) + iznos;
        placeniDnevni++;
        console.log(`     ✅ ${putnik.ime || 'Nepoznato'} -> ${vozac}: ${iznos.toFixed(0)} RSD`);
      }
    });

    console.log(`   📈 Ukupno dnevni: ${ukupnoDnevni.toFixed(0)} RSD (${placeniDnevni} plaćenih)`);
    console.log('');

    // 2. MESEČNI PUTNICI
    console.log('📊 2. MESEČNI PUTNICI (tabela: mesecni_putnici)');
    const mesecniFilters = `?select=vozac,iznosPlacanja,vremePlacanja,putnikIme&aktivan=eq.true&obrisan=eq.false&jePlacen=eq.true&vremePlacanja=gte.${startISO}&vremePlacanja=lte.${endISO}`;
    
    const mesecniPutnici = await makeRequest('mesecni_putnici', mesecniFilters);
    console.log(`   Broj zapisa: ${mesecniPutnici.length}`);

    let ukupnoMesecni = 0;
    let pazarMesecni = {};

    mesecniPutnici.forEach(putnik => {
      const iznos = parseFloat(putnik.iznosPlacanja || 0);
      if (iznos > 0) {
        const vozac = putnik.vozac || 'Nepoznat';
        ukupnoMesecni += iznos;
        pazarMesecni[vozac] = (pazarMesecni[vozac] || 0) + iznos;
        console.log(`     ✅ ${putnik.putnikIme || 'Nepoznato'} -> ${vozac}: ${iznos.toFixed(0)} RSD`);
      }
    });

    console.log(`   📈 Ukupno mesečni: ${ukupnoMesecni.toFixed(0)} RSD`);
    console.log('');

    // 3. UKUPNI REZULTAT
    const ukupnoSvega = ukupnoDnevni + ukupnoMesecni;
    console.log('🏆 === UKUPAN REZULTAT ===');
    console.log(`💰 UKUPNO NAPLAĆENO DANAS: ${ukupnoSvega.toFixed(0)} RSD`);
    console.log(`   - Dnevni putnici: ${ukupnoDnevni.toFixed(0)} RSD`);
    console.log(`   - Mesečni putnici: ${ukupnoMesecni.toFixed(0)} RSD`);
    console.log('');

    // 4. PAZAR PO VOZAČIMA
    console.log('🚗 PAZAR PO VOZAČIMA:');
    const sviVozaci = [...new Set([...Object.keys(pazarDnevni), ...Object.keys(pazarMesecni)])];
    
    sviVozaci.forEach(vozac => {
      const dnevni = pazarDnevni[vozac] || 0;
      const mesecni = pazarMesecni[vozac] || 0;
      const ukupnoVozac = dnevni + mesecni;
      
      if (ukupnoVozac > 0) {
        console.log(`   ${vozac}: ${ukupnoVozac.toFixed(0)} RSD (dnevni: ${dnevni.toFixed(0)}, mesečni: ${mesecni.toFixed(0)})`);
      }
    });

    console.log('');
    console.log('✅ Analiza završena uspešno!');

  } catch (error) {
    console.error('❌ Greška pri analizi:', error.message);
  }
}

analyzePayments();
#!/usr/bin/env node

console.log('🔍 === AUDIT LOGIKE PLAĆANJA U APLIKACIJI ===\n');

console.log('📋 ANALIZA KONZISTENTNOSTI:\n');

console.log('1. 🎯 MESTA GDE SE ČITAJU PLAĆANJA:');
console.log('   • PutnikCard.dart - prikazuje "Plaćeno XXXX"');
console.log('   • MesecniPutnici screen - dugme "XXXXdin"'); 
console.log('   • StatistikaService - računa pazar');
console.log('   • DanasScreen - statistike');
console.log('   • MesecniPutnikDetalji - istorija plaćanja');
console.log('');

console.log('2. 💾 TABELE I KOLONE ZA PLAĆANJA:');
console.log('   📊 MESECNI_PUTNICI:');
console.log('      • cena (glavna kolona za iznos)');
console.log('      • vreme_placanja (kad je plaćeno)');
console.log('      • vozac (ko je naplatio)');
console.log('      • placeni_mesec/placena_godina (legacy)');
console.log('');
console.log('   📊 PUTOVANJA_ISTORIJA:');
console.log('      • cena (iznos plaćanja)');
console.log('      • created_at (vreme)');
console.log('      • status = "placeno"');
console.log('      • putnik_ime (mesečni putnik)');
console.log('');

console.log('3. 🔄 LOGIKA U KODU:');
console.log('   📱 PUTNIK_CARD.DART:');
console.log('      ✅ Koristi _putnik.iznosPlacanja');
console.log('      ✅ Prikazuje "Plaćeno XXXX"');
console.log('      ❓ Ali gde se mapira iznosPlacanja?');
console.log('');
console.log('   📱 MESECNI_PUTNIK MODEL:');
console.log('      ✅ iznosPlacanja => cena ?? ukupnaCenaMeseca');
console.log('      ✅ jePlacen => vremePlacanja != null');
console.log('      ✅ mesecnaKarta => true (uvek)');
console.log('');
console.log('   📱 MESECNI_PUTNICI_SCREEN:');
console.log('      ✅ Dugme: putnik.cena! > 0 ? "XXXXdin" : "Plati"');
console.log('      ✅ Direktno čita putnik.cena iz baze');
console.log('');

console.log('4. ⚠️  POTENCIJALNI PROBLEMI:');
console.log('   🔴 PROBLEM 1: Dupla tabela za plaćanja');
console.log('      • Mesečni putnik može imati cena=0 u mesecni_putnici');
console.log('      • Ali imati plaćanje u putovanja_istorija');
console.log('      • Result: Nekonzistentno prikazivanje!');
console.log('');
console.log('   🔴 PROBLEM 2: StatistikaService logika');
console.log('      • streamPazarZaVozaca koristi kombinovane putnike');
console.log('      • Možda duplo računa mesečne putnike');
console.log('      • Treba proveriti _calculateSimplePazarSync');
console.log('');
console.log('   🔴 PROBLEM 3: MesecniPutnikService vs PutnikService');
console.log('      • Dva različita servisa za plaćanje');
console.log('      • MesecniPutnikService.azurirajPlacanjeZaMesec()');
console.log('      • PutnikService.oznaciPlaceno()');
console.log('      • Možda se podaci čuvaju različito!');
console.log('');

console.log('5. 🎯 PREPORUČENE PROVERE:');
console.log('   1. Uporedi mesecni_putnici.cena vs putovanja_istorija.cena');
console.log('   2. Proveri StatistikaService._calculateSimplePazarSync');
console.log('   3. Proveri PutnikService.getMesecniPutnici()');
console.log('   4. Proveri MesecniPutnikService plaćanje flow');
console.log('   5. Standardizuj jedan način čuvanja plaćanja');
console.log('');

console.log('6. 🔧 PREDLOG REŠENJA:');
console.log('   📋 OPCIJA A: Koristi SAMO mesecni_putnici.cena');
console.log('      • Ukloni plaćanja iz putovanja_istorija za mesečne');
console.log('      • Svi mesečni samo u mesecni_putnici tabeli');
console.log('      • Jednostavnija logika');
console.log('');
console.log('   📋 OPCIJA B: Koristi SAMO putovanja_istorija');
console.log('      • Sva plaćanja u jednoj tabeli');
console.log('      • Mesecni_putnici.cena = NULL uvek');
console.log('      • Konzistentniji pristup');
console.log('');
console.log('   📋 OPCIJA C: Automatska sinhronizacija');
console.log('      • Trigger ili service koji održava obe tabele');
console.log('      • Dupla provera ali uvek konzistentno');
console.log('');

console.log('🎯 === SLEDEĆI KORACI ===');
console.log('1. Analiziraj kod u StatistikaService');
console.log('2. Provi MesecniPutnikService plaćanje');
console.log('3. Proveri PutnikService za mesečne');
console.log('4. Standardizuj jedan pristup');
console.log('5. Napravi migraciju za konzistentnost');

const { spawn } = require('child_process');

console.log('\n🔍 === STVARNA ANALIZA BAZE ===');

function runQuery(query, description) {
  return new Promise((resolve, reject) => {
    console.log(`\n📊 ${description}:`);
    
    const psql = spawn('psql', [
      'postgresql://postgres:postgres@127.0.0.1:54322/postgres',
      '-c', query
    ], { stdio: 'pipe' });
    
    let output = '';
    let error = '';
    
    psql.stdout.on('data', (data) => {
      output += data.toString();
    });
    
    psql.stderr.on('data', (data) => {
      error += data.toString();
    });
    
    psql.on('close', (code) => {
      if (code === 0) {
        console.log(output);
        resolve(output);
      } else {
        console.error(`❌ Greška: ${error}`);
        reject(error);
      }
    });
  });
}

async function analizirajBazu() {
  try {
    // 1. Svi mesečni putnici i njihova plaćanja
    await runQuery(`
      SELECT 
        mp.putnik_ime,
        mp.cena as mesecna_cena,
        mp.vreme_placanja,
        COALESCE(pi_count.broj_placanja, 0) as placanja_u_istoriji,
        COALESCE(pi_sum.ukupno_istorija, 0) as ukupno_istorija
      FROM mesecni_putnici mp
      LEFT JOIN (
        SELECT putnik_ime, COUNT(*) as broj_placanja
        FROM putovanja_istorija 
        WHERE cena > 0 AND status = 'placeno'
        GROUP BY putnik_ime
      ) pi_count ON mp.putnik_ime = pi_count.putnik_ime
      LEFT JOIN (
        SELECT putnik_ime, SUM(cena) as ukupno_istorija
        FROM putovanja_istorija 
        WHERE cena > 0 AND status = 'placeno'
        GROUP BY putnik_ime
      ) pi_sum ON mp.putnik_ime = pi_sum.putnik_ime
      WHERE mp.cena > 0 OR pi_count.broj_placanja > 0
      ORDER BY mp.putnik_ime;
    `, 'Pregled svih mesečnih putnika sa plaćanjima');

    // 2. Nekonzistentnosti
    await runQuery(`
      SELECT 
        'PROBLEM' as tip,
        mp.putnik_ime,
        mp.cena as trebalo_bi,
        pi.cena as ali_u_istoriji,
        'Različite cene!' as opis
      FROM mesecni_putnici mp
      JOIN putovanja_istorija pi ON mp.putnik_ime = pi.putnik_ime
      WHERE mp.cena != pi.cena 
        AND mp.cena > 0 
        AND pi.cena > 0 
        AND pi.status = 'placeno'
      
      UNION ALL
      
      SELECT 
        'MANJKA' as tip,
        mp.putnik_ime,
        mp.cena,
        0 as ali_u_istoriji,
        'Ima cenu ali nema u istoriji' as opis
      FROM mesecni_putnici mp
      LEFT JOIN putovanja_istorija pi ON mp.putnik_ime = pi.putnik_ime AND pi.cena > 0
      WHERE mp.cena > 0 AND pi.putnik_ime IS NULL
      
      UNION ALL
      
      SELECT 
        'VIŠAK' as tip,
        pi.putnik_ime,
        COALESCE(mp.cena, 0) as trebalo_bi,
        pi.cena,
        'Ima u istoriji ali ne u mesečnim' as opis
      FROM putovanja_istorija pi
      LEFT JOIN mesecni_putnici mp ON pi.putnik_ime = mp.putnik_ime
      WHERE pi.cena > 0 AND pi.status = 'placeno' AND (mp.cena IS NULL OR mp.cena = 0);
    `, 'Pronađene nekonzistentnosti');

  } catch (error) {
    console.error('❌ Greška pri analizi baze:', error);
  }
}

analizirajBazu();
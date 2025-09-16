const { createClient } = require('@supabase/supabase-js');

// Supabase konfiguracija
const supabaseUrl = 'https://dwynrrwpcqoygbsjxubz.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR3eW5ycndwY3FveWdic2p4dWJ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjE5ODA1NDMsImV4cCI6MjAzNzU1NjU0M30.kLnHiK_FdyEDJh9c4dHAqNrTu1JMqRv6mz2AeKY-u9g';

const supabase = createClient(supabaseUrl, supabaseKey);

async function testPassengerLoading() {
  console.log('🔍 TESTIRANJE UČITAVANJA PUTNIKA IZ SUPABASE');
  console.log('='.repeat(60));

  try {
    // 1. UKUPAN BROJ MESEČNIH PUTNIKA (sve kolone)
    const { data: sviMesecni, error: errorSvi } = await supabase
      .from('mesecni_putnici')
      .select('id, putnik_ime, aktivan, obrisan')
      .order('putnik_ime');

    if (errorSvi) {
      console.error('❌ Greška pri dohvatanju svih mesečnih:', errorSvi);
      return;
    }

    console.log('\n📊 MESEČNI PUTNICI - UKUPNO:');
    console.log(`   Ukupno zapisa: ${sviMesecni.length}`);
    
    let aktivni = 0, neaktivni = 0, obrisani = 0;
    sviMesecni.forEach(p => {
      if (p.obrisan) obrisani++;
      else if (p.aktivan) aktivni++;
      else neaktivni++;
    });
    
    console.log(`   Aktivni: ${aktivni}`);
    console.log(`   Neaktivni: ${neaktivni}`);
    console.log(`   Obrisani: ${obrisani}`);

    // 2. AKTIVNI MESEČNI PUTNICI (kako aplikacija filtrira)
    const { data: aktivniMesecni, error: errorAktivni } = await supabase
      .from('mesecni_putnici')
      .select('id, putnik_ime, aktivan, obrisan')
      .eq('aktivan', true)
      .order('putnik_ime');

    if (errorAktivni) {
      console.error('❌ Greška pri dohvatanju aktivnih:', errorAktivni);
    } else {
      console.log(`\n✅ AKTIVNI MESEČNI (eq aktivan=true): ${aktivniMesecni.length}`);
    }

    // 3. NEOBRISANI MESEČNI PUTNICI (MesecniPutnikService filtriranje)
    const { data: neobrisaniMesecni, error: errorNeobrisani } = await supabase
      .from('mesecni_putnici')
      .select('id, putnik_ime, aktivan, obrisan')
      .eq('obrisan', false)
      .order('putnik_ime');

    if (errorNeobrisani) {
      console.error('❌ Greška pri dohvatanju neobrisanih:', errorNeobrisani);
    } else {
      console.log(`✅ NEOBRISANI MESEČNI (eq obrisan=false): ${neobrisaniMesecni.length}`);
    }

    // 4. DNEVNI PUTNICI (putovanja_istorija)
    const danas = new Date().toISOString().split('T')[0];
    const { data: dnevniPutnici, error: errorDnevni } = await supabase
      .from('putovanja_istorija')
      .select('id, putnik_ime, datum, tip_putnika')
      .eq('datum', danas)
      .eq('tip_putnika', 'dnevni');

    if (errorDnevni) {
      console.error('❌ Greška pri dohvatanju dnevnih putnika:', errorDnevni);
    } else {
      console.log(`\n🗓️ DNEVNI PUTNICI ZA DANAS (${danas}): ${dnevniPutnici.length}`);
    }

    // 5. UKUPNO PUTOVANJA ISTORIJA
    const { data: svaPutovanja, error: errorSvaPutovanja } = await supabase
      .from('putovanja_istorija')
      .select('id, putnik_ime, datum, tip_putnika')
      .order('datum', { ascending: false })
      .limit(100);

    if (errorSvaPutovanja) {
      console.error('❌ Greška pri dohvatanju putovanja:', errorSvaPutovanja);
    } else {
      console.log(`📋 UKUPNO PUTOVANJA (zadnjih 100): ${svaPutovanja.length}`);
      
      const dnevniCount = svaPutovanja.filter(p => p.tip_putnika === 'dnevni').length;
      const mesecniCount = svaPutovanja.filter(p => p.tip_putnika === 'mesecni').length;
      console.log(`   - Dnevni: ${dnevniCount}`);
      console.log(`   - Mesečni: ${mesecniCount}`);
    }

    console.log('\n' + '='.repeat(60));
    console.log('📝 ZAKLJUČAK:');
    console.log(`   Ukupno mesečnih u bazi: ${sviMesecni.length}`);
    console.log(`   Aplikacija vidi aktivne: ${aktivniMesecni?.length || 0}`);
    console.log(`   Aplikacija vidi neobrisane: ${neobrisaniMesecni?.length || 0}`);
    console.log(`   Dnevni putnici danas: ${dnevniPutnici?.length || 0}`);

    // 6. PROVERAVA RADNE DANE FILTER
    console.log('\n🗓️ ANALIZA RADNIH DANA:');
    const danasNaziv = ['pon', 'uto', 'sre', 'čet', 'pet', 'sub', 'ned'][new Date().getDay() - 1] || 'ned';
    console.log(`   Danas je: ${danasNaziv}`);
    
    const mesecniZaDanas = sviMesecni.filter(p => 
      p.aktivan && 
      !p.obrisan && 
      p.radni_dani && 
      p.radni_dani.toLowerCase().includes(danasNaziv.toLowerCase())
    );
    
    console.log(`   Mesečni putnici koji rade danas: ${mesecniZaDanas.length}`);

  } catch (error) {
    console.error('❌ Greška u testu:', error);
  }
}

testPassengerLoading();
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Inicijalizuj Supabase
  await Supabase.initialize(
    url: 'https://gjtabtwudbrmfeyjiicu.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk',
  );

  final client = Supabase.instance.client;
  final today = DateTime.now();
  final todayIso = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

  print('🔍 Proverava Supabase za datum: $todayIso');

  try {
    // 1. Proverava tabelu putovanja_istorija za današnje naplate
    print('\n📋 1. Proverava putovanja_istorija za danske naplate...');
    final putovanjaResponse = await client
        .from('putovanja_istorija')
        .select('putnik_ime, cena, vreme_placanja, vozac_id, status')
        .eq('datum_putovanja', todayIso)
        .gt('cena', 0)
        .order('created_at');

    print('✅ Pronađeno ${putovanjaResponse.length} naplata u putovanja_istorija:');
    double ukupnoPutovanja = 0;
    for (var item in putovanjaResponse) {
      final cena = (item['cena'] as num?)?.toDouble() ?? 0.0;
      ukupnoPutovanja += cena;
      print('  • ${item['putnik_ime']}: ${cena} RSD (vozac: ${item['vozac_id']}) - Status: ${item['status']}');
    }
    print('  💰 UKUPNO putovanja_istorija: $ukupnoPutovanja RSD');

    // 2. Proverava tabelu mesecni_putnici za današnje naplate
    print('\n📋 2. Proverava mesecni_putnici za danske naplate...');
    final mesecniResponse = await client
        .from('mesecni_putnici')
        .select('putnik_ime, cena, vreme_placanja, vozac_id')
        .not('vreme_placanja', 'is', null)
        .gt('cena', 0);

    // Filtriraj po današnjem datumu
    List<dynamic> mesecniDanas = [];
    double ukupnoMesecni = 0;
    for (var item in mesecniResponse) {
      final vremePlacanja = item['vreme_placanja'];
      if (vremePlacanja != null) {
        final placanjeDate = DateTime.parse(vremePlacanja as String);
        if (placanjeDate.year == today.year && placanjeDate.month == today.month && placanjeDate.day == today.day) {
          mesecniDanas.add(item);
          final cena = (item['cena'] as num?)?.toDouble() ?? 0.0;
          ukupnoMesecni += cena;
        }
      }
    }

    print('✅ Pronađeno ${mesecniDanas.length} mesečnih naplata za danas:');
    for (var item in mesecniDanas) {
      final cena = (item['cena'] as num?)?.toDouble() ?? 0.0;
      print('  • ${item['putnik_ime']}: ${cena} RSD (vozac: ${item['vozac_id']})');
    }
    print('  💰 UKUPNO mesecni_putnici: $ukupnoMesecni RSD');

    // 3. Proverava daily_checkins tabelu za Bojan vozača
    print('\n📋 3. Proverava daily_checkins za vozača Bojan...');
    try {
      final checkinResponse = await client
          .from('daily_checkins')
          .select('amount, pazari, created_at')
          .eq('vozac', 'Bojan')
          .gte('created_at', '${todayIso}T00:00:00')
          .lt('created_at', '${today.add(const Duration(days: 1)).toIso8601String().split('T')[0]}T00:00:00');

      print('✅ Pronađeno ${checkinResponse.length} daily_checkins za Bojan:');
      for (var item in checkinResponse) {
        print('  • Amount: ${item['amount']} RSD, Pazari: ${item['pazari']} RSD, Vreme: ${item['created_at']}');
      }
    } catch (e) {
      print('⚠️ Greška sa daily_checkins tabbelom: $e');
    }

    // 4. UKUPAN PAZAR ZA DANAS
    final ukupanPazar = ukupnoPutovanja + ukupnoMesecni;
    print('\n🎯 REZIME ZA DANAS ($todayIso):');
    print('  📊 Putovanja istorija: $ukupnoPutovanja RSD');
    print('  📊 Mesečni putnici: $ukupnoMesecni RSD');
    print('  💰 UKUPNO: $ukupanPazar RSD');

    if (ukupanPazar < 11000) {
      print('\n⚠️ PROBLEM: Očekivano je 11000 RSD, ali pronađeno je samo $ukupanPazar RSD!');
      print('   Razlika: ${11000 - ukupanPazar} RSD');
      print('   Potrebno je dodati naplate ili proveriti da li su sačuvane u bazi.');
    } else if (ukupanPazar >= 11000) {
      print('\n✅ ODLIČNO: Pronađeno je $ukupanPazar RSD - što je više od očekivanih 11000 RSD!');
    }
  } catch (e) {
    print('❌ Greška pri proveri baze: $e');
  }

  print('\n🔚 Provera završena.');
  exit(0);
}

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/services/statistika_service.dart';
import 'package:gavra_android/services/real_time_statistika_service.dart';
import 'package:gavra_android/services/putnik_service.dart';
import 'package:gavra_android/services/mesecni_putnik_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gavra_android/supabase_client.dart';

/// 🔍 TEST KONZISTENTNOSTI SUPABASE PODATAKA
/// Poredi direktne Supabase query-je sa aplikacionom logikom
void main() {
  group('Supabase Data Consistency Tests', () {
    setUpAll(() async {
      // Inicijalizuj Supabase klijent za testiranje
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
    });

    test('Direktan Supabase query vs StatistikaService - dagens pazar',
        () async {
      final now = DateTime.now();
      final danas = DateTime(now.year, now.month, now.day);
      final danasjKraj = DateTime(now.year, now.month, now.day, 23, 59, 59);

      debugPrint('📅 Testiram podatke za: ${danas.toString().split(' ')[0]}');

      // 1. DIREKTAN SUPABASE QUERY
      final client = Supabase.instance.client;

      // DNEVNI PUTNICI
      final dnevniQuery = await client
          .from('putnici')
          .select(
              'naplatioVozac, iznosPlacanja, vremePlacanja, mesecnaKarta, jeOtkazan')
          .gte('vremePlacanja', danas.toIso8601String())
          .lte('vremePlacanja', danasjKraj.toIso8601String())
          .neq('mesecnaKarta', true)
          .neq('jeOtkazan', true);

      // MESEČNI PUTNICI
      final mesecniQuery = await client
          .from('mesecni_putnici')
          .select(
              'vozac, iznosPlacanja, vremePlacanja, aktivan, obrisan, jePlacen')
          .eq('aktivan', true)
          .eq('obrisan', false)
          .eq('jePlacen', true)
          .gte('vremePlacanja', danas.toIso8601String())
          .lte('vremePlacanja', danasjKraj.toIso8601String());

      // RAČUNAJ DIREKTNO IZ QUERY REZULTATA
      double ukupnoDnevni = 0;
      double ukupnoMesecni = 0;

      Map<String, double> pazarDnevni = {};
      Map<String, double> pazarMesecni = {};

      // Procesuj dnevne putnike
      for (final putnik in dnevniQuery) {
        final iznos = (putnik['iznosPlacanja'] ?? 0).toDouble();
        final vozac = putnik['naplatioVozac'] ?? 'Nepoznat';

        if (iznos > 0) {
          ukupnoDnevni += iznos;
          pazarDnevni[vozac] = (pazarDnevni[vozac] ?? 0) + iznos;
        }
      }

      // Procesuj mesečne putnike
      for (final putnik in mesecniQuery) {
        final iznos = (putnik['iznosPlacanja'] ?? 0).toDouble();
        final vozac = putnik['vozac'] ?? 'Nepoznat';

        if (iznos > 0) {
          ukupnoMesecni += iznos;
          pazarMesecni[vozac] = (pazarMesecni[vozac] ?? 0) + iznos;
        }
      }

      final ukupnodirektno = ukupnoDnevni + ukupnoMesecni;

      debugPrint('🗄️ DIREKTAN SUPABASE QUERY:');
      debugPrint(
          '   Dnevni putnici: ${dnevniQuery.length} (${ukupnoDnevni.toStringAsFixed(0)} RSD)');
      debugPrint(
          '   Mesečni putnici: ${mesecniQuery.length} (${ukupnoMesecni.toStringAsFixed(0)} RSD)');
      debugPrint(
          '   UKUPNO DIREKTNO: ${ukupnodirektno.toStringAsFixed(0)} RSD');

      // 2. APLIKACIJSKA LOGIKA (StatistikaService)
      // 3. STATISTIKA SERVICE - proveri da li vraća iste rezultate
      final putnici = await PutnikService().getAllPutniciFromBothTables();
      final mesecniPutnici = await MesecniPutnikService.getAllMesecniPutnici();

      final appResultat = StatistikaService.calculateKombinovanPazarSync(
          putnici, mesecniPutnici, danas, danasjKraj);

      final ukupnoApp = appResultat['_ukupno'] ?? 0;
      final ukupnoAppObicni = appResultat['_ukupno_obicni'] ?? 0;
      final ukupnoAppMesecni = appResultat['_ukupno_mesecni'] ?? 0;

      debugPrint('📱 APLIKACIJSKA LOGIKA:');
      debugPrint('   Putnici ukupno: ${putnici.length}');
      debugPrint('   Mesečni putnici ukupno: ${mesecniPutnici.length}');
      debugPrint('   Obični pazar: ${ukupnoAppObicni.toStringAsFixed(0)} RSD');
      debugPrint(
          '   Mesečni pazar: ${ukupnoAppMesecni.toStringAsFixed(0)} RSD');
      debugPrint('   UKUPNO APP: ${ukupnoApp.toStringAsFixed(0)} RSD');

      // 3. POREĐENJE REZULTATA
      debugPrint('');
      debugPrint('🔍 ANALIZA RAZLIKA:');

      final razlikaDnevni = (ukupnoDnevni - ukupnoAppObicni).abs();
      final razlikaMesecni = (ukupnoMesecni - ukupnoAppMesecni).abs();
      final razlikaUkupno = (ukupnodirektno - ukupnoApp).abs();

      debugPrint('   Razlika dnevni: ${razlikaDnevni.toStringAsFixed(0)} RSD');
      debugPrint(
          '   Razlika mesečni: ${razlikaMesecni.toStringAsFixed(0)} RSD');
      debugPrint('   Razlika ukupno: ${razlikaUkupno.toStringAsFixed(0)} RSD');

      if (razlikaUkupno < 1.0) {
        debugPrint('✅ PODATCI SU KONZISTENTNI!');
      } else {
        debugPrint('❌ POSTOJE RAZLIKE - trebaju dodatne analize');

        // Detaljnija analiza po vozačima
        debugPrint('');
        debugPrint('📊 DETALJNO PO VOZAČIMA:');
        final sviVozaci = {
          ...pazarDnevni.keys,
          ...pazarMesecni.keys,
          ...appResultat.keys
        }.where((k) => !k.startsWith('_')).toSet();

        for (final vozac in sviVozaci) {
          final direktnoDnevni = pazarDnevni[vozac] ?? 0;
          final direktnoMesecni = pazarMesecni[vozac] ?? 0;
          final direktnoUkupno = direktnoDnevni + direktnoMesecni;
          final appVozac = appResultat[vozac] ?? 0;
          final razlika = (direktnoUkupno - appVozac).abs();

          if (razlika > 0.5) {
            debugPrint(
                '   ⚠️ $vozac: direktno=${direktnoUkupno.toStringAsFixed(0)}, app=${appVozac.toStringAsFixed(0)}, razlika=${razlika.toStringAsFixed(0)}');
          }
        }
      }

      // Test assertion
      expect(razlikaUkupno, lessThan(1.0),
          reason:
              'Razlika između direktnog query-ja i aplikacijske logike ne sme biti veća od 1 RSD');
    });

    test('Real-time stream vs direktan query konzistentnost', () async {
      final now = DateTime.now();
      final danas = DateTime(now.year, now.month, now.day);
      final danasjKraj = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // 1. REAL-TIME STREAM REZULTAT
      final streamResultat = await RealTimeStatistikaService.instance
          .getPazarStream(from: danas, to: danasjKraj)
          .first;

      final ukupnoStream = streamResultat['_ukupno'] ?? 0;

      // 2. DIREKTAN QUERY (kao u prethodnom testu)
      final client = Supabase.instance.client;

      final dnevniQuery = await client
          .from('putnici')
          .select('iznosPlacanja, vremePlacanja, mesecnaKarta, jeOtkazan')
          .gte('vremePlacanja', danas.toIso8601String())
          .lte('vremePlacanja', danasjKraj.toIso8601String())
          .neq('mesecnaKarta', true)
          .neq('jeOtkazan', true);

      final mesecniQuery = await client
          .from('mesecni_putnici')
          .select('iznosPlacanja, vremePlacanja, aktivan, obrisan, jePlacen')
          .eq('aktivan', true)
          .eq('obrisan', false)
          .eq('jePlacen', true)
          .gte('vremePlacanja', danas.toIso8601String())
          .lte('vremePlacanja', danasjKraj.toIso8601String());

      final ukupnoDirectno = dnevniQuery.fold<double>(
              0, (sum, p) => sum + ((p['iznosPlacanja'] ?? 0).toDouble())) +
          mesecniQuery.fold<double>(
              0, (sum, p) => sum + ((p['iznosPlacanja'] ?? 0).toDouble()));

      debugPrint('🔄 STREAM REZULTAT: ${ukupnoStream.toStringAsFixed(0)} RSD');
      debugPrint(
          '🗄️ DIREKTAN QUERY: ${ukupnoDirectno.toStringAsFixed(0)} RSD');

      final razlika = (ukupnoStream - ukupnoDirectno).abs();
      debugPrint('🔍 RAZLIKA: ${razlika.toStringAsFixed(0)} RSD');

      expect(razlika, lessThan(1.0),
          reason: 'Real-time stream i direktan query moraju biti konzistentni');
    });
  });
}

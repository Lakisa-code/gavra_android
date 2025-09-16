import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mesecni_putnik.dart';
import '../models/putnik.dart';

class PassengerLoadingDebugService {
  static final _supabase = Supabase.instance.client;

  /// 🔍 DEBUG: Kompletna analiza učitavanja putnika
  static Future<void> debugPassengerLoading() async {
    if (!kDebugMode) return;

    debugPrint('🔍 ==============================');
    debugPrint('🔍 DEBUG UČITAVANJE PUTNIKA IZ SUPABASE');
    debugPrint('🔍 ==============================');

    try {
      // 1. UKUPAN BROJ MESEČNIH PUTNIKA
      final sviMesecniResponse = await _supabase
          .from('mesecni_putnici')
          .select('id, putnik_ime, aktivan, obrisan, radni_dani')
          .order('putnik_ime');

      debugPrint('📊 MESEČNI PUTNICI - UKUPNO: ${sviMesecniResponse.length}');

      int aktivni = 0, neaktivni = 0, obrisani = 0;
      for (final putnik in sviMesecniResponse) {
        if (putnik['obrisan'] == true) {
          obrisani++;
        } else if (putnik['aktivan'] == true) {
          aktivni++;
        } else {
          neaktivni++;
        }
      }

      debugPrint('   ✅ Aktivni: $aktivni');
      debugPrint('   ❌ Neaktivni: $neaktivni');
      debugPrint('   🗑️ Obrisani: $obrisani');

      // 2. ANALIZA RADNIH DANA
      final danas = DateTime.now();
      final danasKratica = _getDayAbbreviation(danas.weekday);
      debugPrint('🗓️ DANAS JE: ${danas.weekday} ($danasKratica)');

      int radeDanas = 0;
      for (final putnik in sviMesecniResponse) {
        if (putnik['aktivan'] == true &&
            putnik['obrisan'] != true &&
            putnik['radni_dani'] != null) {
          final radniDani = putnik['radni_dani'].toString().toLowerCase();
          if (radniDani.contains(danasKratica.toLowerCase())) {
            radeDanas++;
            debugPrint(
                '   📅 ${putnik['putnik_ime']}: radi danas ($radniDani)');
          }
        }
      }
      debugPrint('👷 MESEČNI PUTNICI KOJI RADE DANAS: $radeDanas');

      // 3. STREAM FUNKCIJE TEST
      debugPrint('\n🔄 TEST STREAM FUNKCIJA:');

      // Test MesecniPutnikService.streamMesecniPutnici
      final streamMesecni =
          await _supabase.from('mesecni_putnici').select().order('putnik_ime');

      final allMesecni =
          streamMesecni.map((json) => MesecniPutnik.fromMap(json)).toList();
      final filteredMesecni =
          allMesecni.where((putnik) => !putnik.obrisan).toList();

      debugPrint('   📊 streamMesecniPutnici simulacija:');
      debugPrint('      - Ukupno iz baze: ${allMesecni.length}');
      debugPrint('      - Nakon filter (!obrisan): ${filteredMesecni.length}');

      // 4. DNEVNI PUTNICI
      final danasString = danas.toIso8601String().split('T')[0];
      final dnevniResponse = await _supabase
          .from('putovanja_istorija')
          .select('*')
          .eq('datum', danasString)
          .eq('tip_putnika', 'dnevni');

      debugPrint(
          '🗓️ DNEVNI PUTNICI ZA DANAS ($danasString): ${dnevniResponse.length}');

      // 5. KOMBINOVANI STREAM SIMULACIJA
      debugPrint('\n🔄 KOMBINOVANI STREAM SIMULACIJA:');

      int kombinovaniCount = 0;

      // Mesečni putnici koji rade danas
      for (final item in sviMesecniResponse) {
        if (item['radni_dani'] != null) {
          final radniDani = item['radni_dani'].toString();
          if (radniDani.toLowerCase().contains(danasKratica.toLowerCase())) {
            final mesecniPutnici = Putnik.fromMesecniPutniciMultiple(item);
            kombinovaniCount += mesecniPutnici.length;
          }
        }
      }

      // Dodaj dnevne putnike
      kombinovaniCount += dnevniResponse.length;

      debugPrint('   🔢 Ukupno u kombinovanom stream-u: $kombinovaniCount');
      debugPrint(
          '      - Mesečni koji rade danas: ${kombinovaniCount - dnevniResponse.length}');
      debugPrint('      - Dnevni za danas: ${dnevniResponse.length}');

      // 6. MOGUĆI PROBLEMI
      debugPrint('\n🚨 ANALIZA MOGUĆIH PROBLEMA:');

      if (obrisani > 0) {
        debugPrint(
            '   ⚠️ Ima $obrisani obrisanih putnika - možda se ne filtriraju dobro');
      }

      if (neaktivni > 0) {
        debugPrint(
            '   ⚠️ Ima $neaktivni neaktivnih putnika - možda se ne prikazuju');
      }

      if (radeDanas < aktivni) {
        debugPrint(
            '   ⚠️ Samo $radeDanas od $aktivni aktivnih putnika radi danas');
        debugPrint('   💡 Proverite radni_dani filter logiku');
      }
    } catch (e) {
      debugPrint('❌ GREŠKA U DEBUG ANALIZI: $e');
    }

    debugPrint('🔍 ==============================');
  }

  static String _getDayAbbreviation(int weekday) {
    switch (weekday) {
      case 1:
        return 'pon';
      case 2:
        return 'uto';
      case 3:
        return 'sre';
      case 4:
        return 'čet';
      case 5:
        return 'pet';
      case 6:
        return 'sub';
      case 7:
        return 'ned';
      default:
        return 'ned';
    }
  }
}

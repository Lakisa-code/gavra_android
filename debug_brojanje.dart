import 'package:gavra_android/services/putnik_service.dart';
import 'package:gavra_android/utils/slot_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🔍 DEBUG SKRIPTA: Analizira razliku između Home i Danas screen brojanja
void main() async {
  print('🔍 === ANALIZA BROJANJA PUTNIKA ===');

  try {
    // Initialize Supabase (koristiti credentials iz app-a)
    await Supabase.initialize(
      url: 'https://mzhksccddrjzqzjroeea.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im16aGtzY2NkZHJqenF6anJvZWVhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjY4NDcxNjQsImV4cCI6MjA0MjQyMzE2NH0.t5X_dKSbP2YlQwKJj9JyBZMYyKv9TpT3q-zJNZsqhIY',
    );

    final putnikService = PutnikService();
    final danas = DateTime.now().toIso8601String().split('T')[0];

    print('🔍 Današnji datum: $danas');
    print('🔍 ');

    // 1. TESTIRA HOME SCREEN LOGIKU
    print('🏠 === HOME SCREEN ANALIZA ===');
    final homePutnici = await putnikService.getAllPutniciFromBothTables();
    final homeSlotCounts = SlotUtils.computeSlotCountsForDate(homePutnici, danas);
    final homeBc6 = homeSlotCounts['BC']?['6:00'] ?? 0;

    print('🏠 Home Screen BC 6:00: $homeBc6');
    print('🏠 ');

    // 2. TESTIRA DANAS SCREEN LOGIKU
    print('📅 === DANAS SCREEN ANALIZA ===');
    final danasPutnici = await putnikService
        .streamKombinovaniPutniciFiltered(
          isoDate: danas,
        )
        .first;
    final danasSlotCounts = SlotUtils.computeSlotCountsForDate(danasPutnici, danas);
    final danasBc6 = danasSlotCounts['BC']?['6:00'] ?? 0;

    print('📅 Danas Screen BC 6:00: $danasBc6');
    print('📅 ');

    // 3. UPOREDI REZULTATE
    print('🎯 === POREĐENJE ===');
    print('🎯 Home Screen: $homeBc6 putnika');
    print('🎯 Danas Screen: $danasBc6 putnika');
    print('🎯 Razlika: ${(homeBc6 - danasBc6).abs()}');

    if (homeBc6 == danasBc6) {
      print('✅ IDENTIČNI BROJEVI - Problem rešen!');
    } else {
      print('❌ RAZLIČITI BROJEVI - Treba dalja analiza!');

      // Analiziraj razlike u podacima
      print('🔍 ');
      print('🔍 === DETALJANA ANALIZA ===');

      final homeIds = homePutnici.map((p) => '${p.id}_${p.polazak}').toSet();
      final danasIds = danasPutnici.map((p) => '${p.id}_${p.polazak}').toSet();

      final samouHome = homeIds.difference(danasIds);
      final samouDanas = danasIds.difference(homeIds);

      print('🔍 Putnici samo u Home: ${samouHome.length}');
      print('🔍 Putnici samo u Danas: ${samouDanas.length}');

      if (samouHome.isNotEmpty) {
        print('🔍 Samo u Home:');
        for (final id in samouHome.take(5)) {
          final putnik = homePutnici.firstWhere((p) => '${p.id}_${p.polazak}' == id);
          print('  - ${putnik.ime}, ${putnik.polazak}, grad=${putnik.grad}, datum=${putnik.datum}');
        }
      }

      if (samouDanas.isNotEmpty) {
        print('🔍 Samo u Danas:');
        for (final id in samouDanas.take(5)) {
          final putnik = danasPutnici.firstWhere((p) => '${p.id}_${p.polazak}' == id);
          print('  - ${putnik.ime}, ${putnik.polazak}, grad=${putnik.grad}, datum=${putnik.datum}');
        }
      }
    }
  } catch (e, stackTrace) {
    print('🚨 Greška u analizi: $e');
    print('🚨 Stack trace: $stackTrace');
  }
}

import 'dart:async';

import '../globals.dart';

/// Servis za rad sa daily_reports tabelom
/// 🎯 KORISTI DIREKTNE KOLONE - SVE DECIMAL/VARCHAR umesto JSONB
class DailyReportsService {
  /// Cache za brže učitavanje
  static final Map<String, Map<String, dynamic>> _cache = {};
  static DateTime? _lastCacheUpdate;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// 🛰️ REALTIME STREAM: Prati promene u tabeli 'daily_reports'
  static Stream<List<Map<String, dynamic>>> streamDailyReports() {
    return supabase
        .from('daily_reports')
        .stream(primaryKey: ['id'])
        .order('updated_at', ascending: false)
        .map((data) => data.map((json) => json).toList());
  }

  /// Stream za specifičnog vozača
  static Stream<List<Map<String, dynamic>>> streamReportsForVozac(String vozac) {
    return supabase
        .from('daily_reports')
        .stream(primaryKey: ['id'])
        .eq('vozac', vozac)
        .order('datum', ascending: false)
        .map((data) => data.map((json) => json).toList());
  }

  /// Stream za današnje report-e
  static Stream<List<Map<String, dynamic>>> streamTodayReports() {
    final today = DateTime.now().toIso8601String().split('T')[0];
    return supabase
        .from('daily_reports')
        .stream(primaryKey: ['id'])
        .eq('datum', today)
        .order('updated_at', ascending: false)
        .map((data) => data.map((json) => json).toList());
  }

  /// Dobija report za vozača i datum
  static Future<Map<String, dynamic>?> getReportForVozacAndDate(String vozac, DateTime datum) async {
    try {
      final datumStr = datum.toIso8601String().split('T')[0];
      final response =
          await supabase.from('daily_reports').select().eq('vozac', vozac).eq('datum', datumStr).maybeSingle();

      return response;
    } catch (e) {
      return null;
    }
  }

  /// Dobija sve report-e za vozača
  static Future<List<Map<String, dynamic>>> getReportsForVozac(String vozac) async {
    try {
      final response =
          await supabase.from('daily_reports').select().eq('vozac', vozac).order('datum', ascending: false);

      return response.map((json) => json).toList();
    } catch (e) {
      return [];
    }
  }

  /// Dobija report-e za određeni datum
  static Future<List<Map<String, dynamic>>> getReportsForDate(DateTime datum) async {
    try {
      final datumStr = datum.toIso8601String().split('T')[0];
      final response = await supabase.from('daily_reports').select().eq('datum', datumStr).order('vozac');

      return response.map((json) => json).toList();
    } catch (e) {
      return [];
    }
  }

  /// Kreira ili ažurira daily report
  static Future<Map<String, dynamic>?> upsertReport(Map<String, dynamic> reportData) async {
    try {
      // Osiguraj updated_at
      reportData['updated_at'] = DateTime.now().toIso8601String();

      final response =
          await supabase.from('daily_reports').upsert(reportData, onConflict: 'vozac,datum').select().single();

      return response;
    } catch (e) {
      return null;
    }
  }

  /// Briše report
  static Future<bool> deleteReport(String vozac, DateTime datum) async {
    try {
      final datumStr = datum.toIso8601String().split('T')[0];
      await supabase.from('daily_reports').delete().eq('vozac', vozac).eq('datum', datumStr);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Dobija statistiku za period
  static Future<Map<String, dynamic>> getStatsForPeriod(DateTime startDate, DateTime endDate) async {
    try {
      final startStr = startDate.toIso8601String().split('T')[0];
      final endStr = endDate.toIso8601String().split('T')[0];

      final response = await supabase.from('daily_reports').select().gte('datum', startStr).lte('datum', endStr);

      final reports = response.map((json) => json).toList();

      // Izračunaj statistiku
      double totalPazar = 0;
      double totalSitanNovac = 0;
      int totalOtkazani = 0;
      int totalNaplaceni = 0;
      int totalPokupljeni = 0;
      int totalDugovi = 0;
      int totalMesecne = 0;
      double totalKilometraza = 0;

      for (final report in reports) {
        totalPazar += (report['ukupan_pazar'] as num?)?.toDouble() ?? 0;
        totalSitanNovac += (report['sitan_novac'] as num?)?.toDouble() ?? 0;
        totalOtkazani += (report['otkazani_putnici'] as int?) ?? 0;
        totalNaplaceni += (report['naplaceni_putnici'] as int?) ?? 0;
        totalPokupljeni += (report['pokupljeni_putnici'] as int?) ?? 0;
        totalDugovi += (report['dugovi_putnici'] as int?) ?? 0;
        totalMesecne += (report['mesecne_karte'] as int?) ?? 0;
        totalKilometraza += (report['kilometraza'] as num?)?.toDouble() ?? 0;
      }

      return {
        'total_reports': reports.length,
        'ukupan_pazar': totalPazar,
        'sitan_novac': totalSitanNovac,
        'otkazani_putnici': totalOtkazani,
        'naplaceni_putnici': totalNaplaceni,
        'pokupljeni_putnici': totalPokupljeni,
        'dugovi_putnici': totalDugovi,
        'mesecne_karte': totalMesecne,
        'kilometraza': totalKilometraza,
        'period_days': endDate.difference(startDate).inDays + 1,
      };
    } catch (e) {
      return {};
    }
  }
}

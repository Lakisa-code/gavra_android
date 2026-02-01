import 'dart:async';

import '../globals.dart';
import '../services/realtime/realtime_manager.dart';
import '../services/voznje_log_service.dart';

/// Servis za globalna podešavanja aplikacije iz Supabase
class AppSettingsService {
  AppSettingsService._();

  static StreamSubscription? _subscription;

  /// Inicijalizuje listener na app_settings tabelu
  static Future<void> initialize() async {
    // Učitaj početne vrednosti
    await _loadSettings();

    // Slušaj promene u realtime
    _subscription = RealtimeManager.instance.subscribe('app_settings').listen((payload) {
      // Na svaku promenu, ponovo učitaj podešavanja
      _loadSettings();
    });
  }

  /// Učitaj sva podešavanja iz baze
  static Future<void> _loadSettings() async {
    try {
      final response = await supabase
          .from('app_settings')
          .select('nav_bar_type, dnevni_zakazivanje_aktivno')
          .eq('id', 'global')
          .single();

      final navBarType = response['nav_bar_type'] as String? ?? 'auto';
      navBarTypeNotifier.value = navBarType;
      praznicniModNotifier.value = navBarType == 'praznici';

      final dnevniAktivno = response['dnevni_zakazivanje_aktivno'] as bool? ?? false;
      dnevniZakazivanjeNotifier.value = dnevniAktivno;
    } catch (e) {
      // Ako nema reda, ostavi default vrednosti
    }
  }

  /// Postavi nav_bar_type (samo admin može)
  static Future<void> setNavBarType(String type) async {
    await supabase.from('app_settings').update({
      'nav_bar_type': type,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', 'global');

    // 📝 LOG U DNEVNIK
    try {
      await VoznjeLogService.logGeneric(
        tip: 'admin_akcija',
        detalji: 'Promenjen red vožnje na: ${type.toUpperCase()}',
      );
    } catch (_) {}
  }

  /// Postavi dnevni_zakazivanje_aktivno (samo admin može)
  static Future<void> setDnevniZakazivanjeAktivno(bool aktivno) async {
    await supabase.from('app_settings').update({
      'dnevni_zakazivanje_aktivno': aktivno,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', 'global');

    // 📝 LOG U DNEVNIK
    try {
      await VoznjeLogService.logGeneric(
        tip: 'admin_akcija',
        detalji: 'Zakazivanje za dnevne putnike: ${aktivno ? "UKLJUČENO" : "ISKLJUČENO"}',
      );
    } catch (_) {}
  }

  /// Cleanup
  static void dispose() {
    _subscription?.cancel();
  }
}

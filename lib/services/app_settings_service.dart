import 'dart:async';

import '../globals.dart';

/// Servis za globalna podešavanja aplikacije iz Supabase
class AppSettingsService {
  AppSettingsService._();

  static StreamSubscription? _subscription;

  /// Inicijalizuje listener na app_settings tabelu
  static Future<void> initialize() async {
    // Učitaj početne vrednosti
    await _loadSettings();

    // Slušaj promene u realtime
    _subscription = supabase.from('app_settings').stream(primaryKey: ['id']).eq('id', 'global').listen((data) {
          if (data.isNotEmpty) {
            final row = data.first;

            // Nav bar type
            final navBarType = row['nav_bar_type'] as String? ?? 'auto';
            navBarTypeNotifier.value = navBarType;
            // Sync sa starim praznicniModNotifier za backward compatibility
            praznicniModNotifier.value = navBarType == 'praznici';

            // Dnevni zakazivanje
            final dnevniAktivno = row['dnevni_zakazivanje_aktivno'] as bool? ?? false;
            dnevniZakazivanjeNotifier.value = dnevniAktivno;
          }
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
  }

  /// Postavi dnevni_zakazivanje_aktivno (samo admin može)
  static Future<void> setDnevniZakazivanjeAktivno(bool aktivno) async {
    await supabase.from('app_settings').update({
      'dnevni_zakazivanje_aktivno': aktivno,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', 'global');
  }

  /// Cleanup
  static void dispose() {
    _subscription?.cancel();
  }
}

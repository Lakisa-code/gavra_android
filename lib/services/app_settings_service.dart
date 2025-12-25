import 'dart:async';

import '../globals.dart';

/// Servis za globalna podešavanja aplikacije iz Supabase
class AppSettingsService {
  AppSettingsService._();

  static StreamSubscription? _subscription;

  /// Inicijalizuje listener na app_settings tabelu
  static Future<void> initialize() async {
    // Učitaj početnu vrednost
    await _loadNavBarType();

    // Slušaj promene u realtime
    _subscription = supabase.from('app_settings').stream(primaryKey: ['id']).eq('id', 'global').listen((data) {
          if (data.isNotEmpty) {
            final navBarType = data.first['nav_bar_type'] as String? ?? 'auto';
            navBarTypeNotifier.value = navBarType;
            // Sync sa starim praznicniModNotifier za backward compatibility
            praznicniModNotifier.value = navBarType == 'praznici';
          }
        });
  }

  /// Učitaj nav_bar_type iz baze
  static Future<void> _loadNavBarType() async {
    try {
      final response = await supabase.from('app_settings').select('nav_bar_type').eq('id', 'global').single();

      final navBarType = response['nav_bar_type'] as String? ?? 'auto';
      navBarTypeNotifier.value = navBarType;
      praznicniModNotifier.value = navBarType == 'praznici';
    } catch (e) {
      // Ako nema reda, ostavi default 'auto'
    }
  }

  /// Postavi nav_bar_type (samo admin može)
  static Future<void> setNavBarType(String type) async {
    await supabase.from('app_settings').update({
      'nav_bar_type': type,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', 'global');
  }

  /// Cleanup
  static void dispose() {
    _subscription?.cancel();
  }
}

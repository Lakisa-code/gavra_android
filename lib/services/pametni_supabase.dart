// 📊 SUPABASE USAGE MONITOR
// ❓ НЕ ЗНАМ ДА ЛИ СЕ КОРИСТИ - ПРОВЕРИТИ!
//
// Овај сервис прати колико често се приступа Supabase бази.
// Можда се не користи активно у апликацији.

import 'package:supabase_flutter/supabase_flutter.dart';

import 'simple_usage_monitor.dart';

/// Pametan Supabase klijent koji automatski prati pozive
/// Koristite ovaj umesto običnog supabase klijenta
class PametniSupabase {
  static final _supabase = Supabase.instance.client;

  /// Koristite ovako: PametniSupabase.from('tabela').select()
  static SupabaseQueryBuilder from(String tabela) {
    // Automatski broji poziv (bez await da ne blokira)
    SimpleUsageMonitor.brojPoziv().catchError((e) => null);

    // Vraća normalan Supabase query
    return _supabase.from(tabela);
  }

  /// Ostale Supabase funkcije
  static GoTrueClient get auth => _supabase.auth;
  static SupabaseStorageClient get storage => _supabase.storage;
  static RealtimeClient get realtime => _supabase.realtime;

  /// RPC pozivi se takođe broje
  static Future<dynamic> rpc(String funkcija, {Map<String, dynamic>? params}) async {
    // Broji poziv asinhrono
    SimpleUsageMonitor.brojPoziv().catchError((e) => null);
    return _supabase.rpc(funkcija, params: params);
  }
}

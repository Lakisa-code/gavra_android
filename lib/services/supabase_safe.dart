// 🛡️ SUPABASE SAFE WRAPPER
// ✅ КОРИСТИ СЕ У АПЛИКАЦИЈИ - НЕ БРИСАТИ!
//
// Овај сервис "обавија" Supabase позиве у try-catch блокове
// и спречава crash-ове ако нека табела не постоји или има грешке.
// Користи се у: sms_service, ruta_service, realtime_service, итд.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logging.dart';

class SupabaseSafe {
  static final _client = Supabase.instance.client;

  /// Safely runs a select on [table] with optional [columns]. Returns the raw
  /// response (List/Map) or an empty list if the table doesn't exist or an
  /// error occurs.
  static Future<dynamic> select(String table, {String? columns}) async {
    try {
      if (columns != null) {
        return await _client.from(table).select(columns);
      }
      return await _client.from(table).select();
    } on PostgrestException catch (e) {
      dlog('❌ [SUPABASE SAFE] PostgrestException for $table: ${e.message}');
      return <dynamic>[];
    } catch (e) {
      dlog('❌ [SUPABASE SAFE] Error selecting $table: $e');
      return <dynamic>[];
    }
  }

  static Future<dynamic> delete(
    String table,
    String column,
    String value,
  ) async {
    try {
      return await _client.from(table).delete().eq(column, value);
    } on PostgrestException catch (e) {
      dlog(
        '❌ [SUPABASE SAFE] PostgrestException on delete $table: ${e.message}',
      );
      return <dynamic>[];
    } catch (e) {
      dlog('❌ [SUPABASE SAFE] Error deleting from $table: $e');
      return <dynamic>[];
    }
  }

  static Future<dynamic> rpc(String fn, {Map<String, dynamic>? params}) async {
    try {
      return await _client.rpc(fn, params: params);
    } on PostgrestException catch (e) {
      dlog('❌ [SUPABASE SAFE] PostgrestException on rpc $fn: ${e.message}');
      return <dynamic>[];
    } catch (e) {
      dlog('❌ [SUPABASE SAFE] Error calling rpc $fn: $e');
      return <dynamic>[];
    }
  }

  /// Run an arbitrary Supabase Future-returning function and return [fallback]
  /// if it throws a PostgrestException or any other error. Useful for chained
  /// queries like `.from(...).select().eq()...` where we want to catch table-missing
  /// errors in one place.
  static Future<T?> run<T>(Future<T> Function() fn, {T? fallback}) async {
    try {
      return await fn();
    } on PostgrestException catch (e) {
      dlog('❌ [SUPABASE SAFE] PostgrestException in run: ${e.message}');
      return fallback;
    } catch (e) {
      dlog('❌ [SUPABASE SAFE] Error in run: $e');
      return fallback;
    }
  }
}

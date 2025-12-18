// SUPABASE SAFE WRAPPER
library;
// КОРИСТИ СЕ У АПЛИКАЦИЈИ - НЕ БРИСАТИ!
//
// Овај сервис "обавија" Supabase позиве у try-catch блокове
// и спречава crash-ове ако нека табела не постоји или има грешке.
// Користи се у: sms_service, ruta_service, realtime_service, итд.

import 'package:supabase_flutter/supabase_flutter.dart';

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
    } on PostgrestException {
      // Error handling - logging removed for production
      return <dynamic>[];
    } catch (e) {
      // Error handling - logging removed for production
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
    } on PostgrestException {
      // Error handling - logging removed for production
      return <dynamic>[];
    } catch (e) {
      // Error handling - logging removed for production
      return <dynamic>[];
    }
  }

  static Future<dynamic> rpc(String fn, {Map<String, dynamic>? params}) async {
    try {
      return await _client.rpc(fn, params: params);
    } on PostgrestException {
      // Error handling - logging removed for production
      return <dynamic>[];
    } catch (e) {
      // Error handling - logging removed for production
      return <dynamic>[];
    }
  }

  /// Run an arbitrary Supabase Future-returning function and return [fallback]
  /// if it throws a PostgrestException or any other error. Useful for chained
  /// queries like `.from(...).select().eq()...` where we want to catch table-missing
  /// errors in one place.
  static Future<T?> run<T>(Future<T> Function() fn, {T? fallback}) async {
    try {
      final result = await fn();
      return result;
    } on PostgrestException {
      return fallback;
    } catch (_) {
      return fallback;
    }
  }
}

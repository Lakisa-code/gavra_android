import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../models/v2_registrovani_putnik.dart';
import 'realtime/v2_master_realtime_manager.dart';

/// Servis za upravljanje pošiljkama — tabela v2_posiljke
/// Kolone: id, ime, status, telefon, adresa_bc_id, adresa_vs_id, cena, created_at, updated_at
class V2PosiljkaService {
  static SupabaseClient get _supabase => supabase;
  static V2MasterRealtimeManager get _rm => V2MasterRealtimeManager.instance;

  // ---------------------------------------------------------------------------
  // 📖 ČITANJE — iz rm.posiljkeCache (sync, 0 DB upita)
  // ---------------------------------------------------------------------------

  /// Dohvata sve aktivne pošiljke iz rm cache-a (sync)
  static List<RegistrovaniPutnik> getAktivne() {
    return _rm.posiljkeCache.values.map((r) => _fromRow(r)).toList()..sort((a, b) => a.ime.compareTo(b.ime));
  }

  /// Dohvata sve pošiljke iz rm cache-a (sync) — cache sadrži samo aktivne
  static List<RegistrovaniPutnik> getSve() {
    return _rm.posiljkeCache.values.map((r) => _fromRow(r)).toList()..sort((a, b) => a.ime.compareTo(b.ime));
  }

  /// Dohvata pošiljku po ID-u iz rm cache-a (sync)
  static RegistrovaniPutnik? getById(String id) {
    final row = _rm.posiljkeCache[id];
    if (row == null) return null;
    return _fromRow(row);
  }

  /// Dohvata ime pošiljke po ID-u iz rm cache-a (sync)
  static String? getImeById(String id) {
    return _rm.posiljkeCache[id]?['ime'] as String?;
  }

  // ---------------------------------------------------------------------------
  // ✏️ KREIRANJE / AŽURIRANJE
  // ---------------------------------------------------------------------------

  /// Kreira novu pošiljku
  static Future<RegistrovaniPutnik?> create({
    required String ime,
    String? telefon,
    String? adresaBcId,
    String? adresaVsId,
    double? cena,
    String status = 'aktivan',
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final row = await _supabase
          .from('v2_posiljke')
          .insert({
            'ime': ime,
            'telefon': telefon,
            'adresa_bc_id': adresaBcId,
            'adresa_vs_id': adresaVsId,
            'cena': cena,
            'status': status,
            'created_at': now,
            'updated_at': now,
          })
          .select()
          .single();
      return _fromRow(row);
    } catch (e) {
      debugPrint('❌ [V2PosiljkaService] create error: $e');
      return null;
    }
  }

  /// Ažurira pošiljku
  static Future<bool> update(String id, Map<String, dynamic> updates) async {
    try {
      updates['updated_at'] = DateTime.now().toUtc().toIso8601String();
      await _supabase.from('v2_posiljke').update(updates).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('❌ [V2PosiljkaService] update error: $e');
      return false;
    }
  }

  /// Menja status pošiljke (aktivan/neaktivan)
  static Future<bool> setStatus(String id, String status) async {
    return update(id, {'status': status});
  }

  /// Briše pošiljku (trajno)
  static Future<bool> delete(String id) async {
    try {
      await _supabase.from('v2_posiljke').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('❌ [V2PosiljkaService] delete error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // 🔴 REALTIME STREAM — emit iz rm.posiljkeCache (0 DB upita)
  // ---------------------------------------------------------------------------

  /// Stream aktivnih pošiljki (realtime) — emituje direktno iz cache-a
  static Stream<List<RegistrovaniPutnik>> streamAktivne() {
    final controller = StreamController<List<RegistrovaniPutnik>>.broadcast();
    controller.add(getAktivne());
    final sub = _rm.subscribe('v2_posiljke').listen((_) {
      if (!controller.isClosed) controller.add(getAktivne());
    });
    controller.onCancel = () {
      sub.cancel();
      controller.close();
    };
    return controller.stream;
  }

  // ---------------------------------------------------------------------------
  // 🔧 HELPER
  // ---------------------------------------------------------------------------

  /// Konvertuje red iz v2_posiljke u RegistrovaniPutnik model
  static RegistrovaniPutnik _fromRow(Map<String, dynamic> r) {
    return RegistrovaniPutnik.fromMap({
      ...r,
      '_tabela': 'v2_posiljke',
    });
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../models/v2_registrovani_putnik.dart';
import 'realtime/v2_master_realtime_manager.dart';

/// Servis za upravljanje dnevnim putnicima — tabela v2_dnevni
/// Kolone: id, ime, status, telefon, telefon_2, adresa_bc_id, adresa_vs_id, cena, created_at, updated_at
class V2DnevniService {
  static SupabaseClient get _supabase => supabase;

  // ---------------------------------------------------------------------------
  // 📖 ČITANJE
  // ---------------------------------------------------------------------------

  /// Dohvata sve aktivne dnevne putnike
  static List<RegistrovaniPutnik> getAktivne() {
    final rm = V2MasterRealtimeManager.instance;
    return rm.dnevniCache.values.where((r) => r['status'] == 'aktivan').map((r) => _fromRow(r)).toList()
      ..sort((a, b) => a.ime.compareTo(b.ime));
  }

  /// Dohvata sve dnevne putnike (uključujući neaktivne)
  static List<RegistrovaniPutnik> getSve() {
    final rm = V2MasterRealtimeManager.instance;
    return rm.dnevniCache.values.map((r) => _fromRow(r)).toList()..sort((a, b) => a.ime.compareTo(b.ime));
  }

  /// Dohvata dnevnog putnika po ID-u
  static RegistrovaniPutnik? getById(String id) {
    final row = V2MasterRealtimeManager.instance.dnevniCache[id];
    if (row == null) return null;
    return _fromRow(row);
  }

  /// Dohvata ime dnevnog putnika po ID-u
  static String? getImeById(String id) {
    return V2MasterRealtimeManager.instance.dnevniCache[id]?['ime'] as String?;
  }

  // ---------------------------------------------------------------------------
  // ✏️ KREIRANJE / AŽURIRANJE
  // ---------------------------------------------------------------------------

  /// Kreira novog dnevnog putnika
  static Future<RegistrovaniPutnik?> create({
    required String ime,
    String? telefon,
    String? telefon2,
    String? adresaBcId,
    String? adresaVsId,
    double? cena,
    String status = 'aktivan',
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final row = await _supabase
          .from('v2_dnevni')
          .insert({
            'ime': ime,
            'telefon': telefon,
            'telefon_2': telefon2,
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
      debugPrint('❌ [V2DnevniService] create error: $e');
      return null;
    }
  }

  /// Ažurira dnevnog putnika
  static Future<bool> update(String id, Map<String, dynamic> updates) async {
    try {
      updates['updated_at'] = DateTime.now().toUtc().toIso8601String();
      await _supabase.from('v2_dnevni').update(updates).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('❌ [V2DnevniService] update error: $e');
      return false;
    }
  }

  /// Menja status dnevnog putnika (aktivan/neaktivan)
  static Future<bool> setStatus(String id, String status) async {
    return update(id, {'status': status});
  }

  /// Briše dnevnog putnika (trajno)
  static Future<bool> delete(String id) async {
    try {
      await _supabase.from('v2_dnevni').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('❌ [V2DnevniService] delete error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // 🔴 REALTIME STREAM
  // ---------------------------------------------------------------------------

  /// Stream aktivnih dnevnih putnika (realtime) — čita iz rm.dnevniCache, nema DB upita
  static Stream<List<RegistrovaniPutnik>> streamAktivne() {
    final controller = StreamController<List<RegistrovaniPutnik>>.broadcast();
    final rm = V2MasterRealtimeManager.instance;

    void emit() {
      if (!controller.isClosed) {
        controller.add(
          rm.dnevniCache.values.where((r) => r['status'] == 'aktivan').map((r) => _fromRow(r)).toList()
            ..sort((a, b) => a.ime.compareTo(b.ime)),
        );
      }
    }

    emit();
    final sub = rm.subscribe('v2_dnevni').listen((_) => emit());
    controller.onCancel = () {
      sub.cancel();
      rm.unsubscribe('v2_dnevni');
    };

    return controller.stream;
  }

  // ---------------------------------------------------------------------------
  // 🔧 HELPER
  // ---------------------------------------------------------------------------

  /// Konvertuje red iz v2_dnevni u RegistrovaniPutnik model
  static RegistrovaniPutnik _fromRow(Map<String, dynamic> r) {
    return RegistrovaniPutnik.fromMap({
      ...r,
      '_tabela': 'v2_dnevni',
    });
  }
}

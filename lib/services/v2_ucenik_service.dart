import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../models/v2_registrovani_putnik.dart';
import 'realtime/v2_master_realtime_manager.dart';

/// Servis za upravljanje učenicima — tabela v2_ucenici
/// Kolone: id, ime, status, telefon, telefon_oca, telefon_majke,
///         adresa_bc_id, adresa_vs_id, pin, email, cena_po_danu, broj_mesta,
///         created_at, updated_at
class V2UcenikService {
  static SupabaseClient get _supabase => supabase;

  // ---------------------------------------------------------------------------
  // 📖 ČITANJE
  // ---------------------------------------------------------------------------

  /// Dohvata sve aktivne učenike
  static List<RegistrovaniPutnik> getAktivne() {
    final rm = V2MasterRealtimeManager.instance;
    return rm.uceniciCache.values.where((r) => r['status'] == 'aktivan').map((r) => _fromRow(r)).toList()
      ..sort((a, b) => a.ime.compareTo(b.ime));
  }

  /// Dohvata sve učenike (uključujući neaktivne)
  static List<RegistrovaniPutnik> getSve() {
    final rm = V2MasterRealtimeManager.instance;
    return rm.uceniciCache.values.map((r) => _fromRow(r)).toList()..sort((a, b) => a.ime.compareTo(b.ime));
  }

  /// Dohvata učenika po ID-u
  static RegistrovaniPutnik? getById(String id) {
    final row = V2MasterRealtimeManager.instance.uceniciCache[id];
    if (row == null) return null;
    return _fromRow(row);
  }

  /// Dohvata ime učenika po ID-u
  static String? getImeById(String id) {
    return V2MasterRealtimeManager.instance.uceniciCache[id]?['ime'] as String?;
  }

  /// Pronalazi učenika po PIN-u (za autentifikaciju)
  static RegistrovaniPutnik? getByPin(String pin) {
    final rm = V2MasterRealtimeManager.instance;
    try {
      final row = rm.uceniciCache.values.firstWhere(
        (r) => r['pin'] == pin && r['status'] == 'aktivan',
      );
      return _fromRow(row);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // ✏️ KREIRANJE / AŽURIRANJE
  // ---------------------------------------------------------------------------

  /// Kreira novog učenika
  static Future<RegistrovaniPutnik?> create({
    required String ime,
    String? telefon,
    String? telefonOca,
    String? telefonMajke,
    String? adresaBcId,
    String? adresaVsId,
    String? pin,
    String? email,
    double? cenaPosDanu,
    int? brojMesta,
    String status = 'aktivan',
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final row = await _supabase
          .from('v2_ucenici')
          .insert({
            'ime': ime,
            'telefon': telefon,
            'telefon_oca': telefonOca,
            'telefon_majke': telefonMajke,
            'adresa_bc_id': adresaBcId,
            'adresa_vs_id': adresaVsId,
            'pin': pin,
            'email': email,
            'cena_po_danu': cenaPosDanu,
            'broj_mesta': brojMesta,
            'status': status,
            'created_at': now,
            'updated_at': now,
          })
          .select()
          .single();
      return _fromRow(row);
    } catch (e) {
      debugPrint('❌ [V2UcenikService] create error: $e');
      return null;
    }
  }

  /// Ažurira učenika
  static Future<bool> update(String id, Map<String, dynamic> updates) async {
    try {
      updates['updated_at'] = DateTime.now().toUtc().toIso8601String();
      await _supabase.from('v2_ucenici').update(updates).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('❌ [V2UcenikService] update error: $e');
      return false;
    }
  }

  /// Menja status učenika (aktivan/neaktivan)
  static Future<bool> setStatus(String id, String status) async {
    return update(id, {'status': status});
  }

  /// Briše učenika (trajno)
  static Future<bool> delete(String id) async {
    try {
      await _supabase.from('v2_ucenici').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('❌ [V2UcenikService] delete error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // 🔴 REALTIME STREAM
  // ---------------------------------------------------------------------------

  /// Stream aktivnih učenika (realtime) — čita iz rm.uceniciCache, nema DB upita
  static Stream<List<RegistrovaniPutnik>> streamAktivne() {
    final controller = StreamController<List<RegistrovaniPutnik>>.broadcast();
    final rm = V2MasterRealtimeManager.instance;

    void emit() {
      if (!controller.isClosed) {
        controller.add(
          rm.uceniciCache.values.where((r) => r['status'] == 'aktivan').map((r) => _fromRow(r)).toList()
            ..sort((a, b) => a.ime.compareTo(b.ime)),
        );
      }
    }

    emit();
    final sub = rm.subscribe('v2_ucenici').listen((_) => emit());
    controller.onCancel = () {
      sub.cancel();
      rm.unsubscribe('v2_ucenici');
    };

    return controller.stream;
  }

  // ---------------------------------------------------------------------------
  // 🔧 HELPER
  // ---------------------------------------------------------------------------

  /// Konvertuje red iz v2_ucenici u RegistrovaniPutnik model
  static RegistrovaniPutnik _fromRow(Map<String, dynamic> r) {
    return RegistrovaniPutnik.fromMap({
      ...r,
      '_tabela': 'v2_ucenici',
    });
  }
}

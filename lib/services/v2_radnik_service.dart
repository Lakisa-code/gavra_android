import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../models/v2_registrovani_putnik.dart';
import 'realtime/v2_master_realtime_manager.dart';

/// Servis za upravljanje radnicima — tabela v2_radnici
/// Kolone: id, ime, status, telefon, telefon_2, adresa_bc_id, adresa_vs_id,
///         pin, email, cena_po_danu, broj_mesta, created_at, updated_at
class V2RadnikService {
  static SupabaseClient get _supabase => supabase;

  // ---------------------------------------------------------------------------
  // 📖 ČITANJE
  // ---------------------------------------------------------------------------

  /// Dohvata sve aktivne radnike
  static List<RegistrovaniPutnik> getAktivne() {
    final rm = V2MasterRealtimeManager.instance;
    return rm.radniciCache.values.where((r) => r['status'] == 'aktivan').map((r) => _fromRow(r)).toList()
      ..sort((a, b) => a.ime.compareTo(b.ime));
  }

  /// Dohvata sve radnike (uključujući neaktivne)
  static List<RegistrovaniPutnik> getSve() {
    final rm = V2MasterRealtimeManager.instance;
    return rm.radniciCache.values.map((r) => _fromRow(r)).toList()..sort((a, b) => a.ime.compareTo(b.ime));
  }

  /// Dohvata radnika po ID-u
  static RegistrovaniPutnik? getById(String id) {
    final row = V2MasterRealtimeManager.instance.radniciCache[id];
    if (row == null) return null;
    return _fromRow(row);
  }

  /// Dohvata ime radnika po ID-u
  static String? getImeById(String id) {
    return V2MasterRealtimeManager.instance.radniciCache[id]?['ime'] as String?;
  }

  /// Pronalazi radnika po PIN-u (za autentifikaciju)
  static RegistrovaniPutnik? getByPin(String pin) {
    final rm = V2MasterRealtimeManager.instance;
    try {
      final row = rm.radniciCache.values.firstWhere(
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

  /// Kreira novog radnika
  static Future<RegistrovaniPutnik?> create({
    required String ime,
    String? telefon,
    String? telefon2,
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
          .from('v2_radnici')
          .insert({
            'ime': ime,
            'telefon': telefon,
            'telefon_2': telefon2,
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
      debugPrint('❌ [V2RadnikService] create error: $e');
      return null;
    }
  }

  /// Ažurira radnika
  static Future<bool> update(String id, Map<String, dynamic> updates) async {
    try {
      updates['updated_at'] = DateTime.now().toUtc().toIso8601String();
      await _supabase.from('v2_radnici').update(updates).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('❌ [V2RadnikService] update error: $e');
      return false;
    }
  }

  /// Menja status radnika (aktivan/neaktivan)
  static Future<bool> setStatus(String id, String status) async {
    return update(id, {'status': status});
  }

  /// Briše radnika (trajno)
  static Future<bool> delete(String id) async {
    try {
      await _supabase.from('v2_radnici').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('❌ [V2RadnikService] delete error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // 🔴 REALTIME STREAM
  // ---------------------------------------------------------------------------

  /// Stream aktivnih radnika (realtime) — čita iz rm.radniciCache, nema DB upita
  static Stream<List<RegistrovaniPutnik>> streamAktivne() {
    final controller = StreamController<List<RegistrovaniPutnik>>.broadcast();
    final rm = V2MasterRealtimeManager.instance;

    void emit() {
      if (!controller.isClosed) {
        controller.add(
          rm.radniciCache.values.where((r) => r['status'] == 'aktivan').map((r) => _fromRow(r)).toList()
            ..sort((a, b) => a.ime.compareTo(b.ime)),
        );
      }
    }

    emit();
    final sub = rm.subscribe('v2_radnici').listen((_) => emit());
    controller.onCancel = () {
      sub.cancel();
      rm.unsubscribe('v2_radnici');
    };

    return controller.stream;
  }

  // ---------------------------------------------------------------------------
  // 🔧 HELPER
  // ---------------------------------------------------------------------------

  /// Konvertuje red iz v2_radnici u RegistrovaniPutnik model
  static RegistrovaniPutnik _fromRow(Map<String, dynamic> r) {
    return RegistrovaniPutnik.fromMap({
      ...r,
      '_tabela': 'v2_radnici',
    });
  }
}

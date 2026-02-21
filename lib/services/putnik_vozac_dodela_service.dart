import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';

/// 👤 PUTNIK VOZAC DODELA SERVICE
/// Individualna dodela vozača po putniku (datum + grad + vreme)
/// Viši prioritet od vreme_vozac (globalna dodela)
/// Koristi se kada 2 kombija voze isti termin
class PutnikVozacDodelaService {
  // Singleton
  static final PutnikVozacDodelaService _instance = PutnikVozacDodelaService._internal();
  factory PutnikVozacDodelaService() => _instance;
  PutnikVozacDodelaService._internal();

  SupabaseClient get _supabase => supabase;

  // Cache: 'putnikId|datum|grad' -> vozac_ime
  final Map<String, String> _cache = {};

  final _changesController = StreamController<void>.broadcast();
  Stream<void> get onChanges => _changesController.stream;

  RealtimeChannel? _realtimeChannel;

  // ─────────────────────────────────────────────────────────────
  // READ
  // ─────────────────────────────────────────────────────────────

  /// Dobij vozača za konkretnog putnika (ASYNC)
  Future<String?> getVozacZaPutnika({
    required String putnikId,
    required String datum,
    required String grad,
  }) async {
    try {
      final gradKey = _normalizeGrad(grad);
      final response = await _supabase
          .from('putnik_vozac_dodela')
          .select('vozac_ime')
          .eq('putnik_id', putnikId)
          .eq('datum', datum)
          .eq('grad', gradKey)
          .maybeSingle();
      return response?['vozac_ime'] as String?;
    } catch (e) {
      debugPrint('⚠️ [PutnikVozacDodela] getVozacZaPutnika: $e');
      return null;
    }
  }

  /// Dobij vozača za konkretnog putnika (SYNC iz cache-a)
  String? getVozacZaPutnikaSync({
    required String putnikId,
    required String datum,
    required String grad,
  }) {
    final gradKey = _normalizeGrad(grad);
    final key = '$putnikId|$datum|$gradKey';
    return _cache[key];
  }

  /// Dohvati sve dodele za određeni datum+grad+vreme (za prikaz liste)
  Future<List<Map<String, dynamic>>> getDodeleZaDatumGradVreme({
    required String datum,
    required String grad,
    required String vreme,
  }) async {
    try {
      final gradKey = _normalizeGrad(grad);
      final response = await _supabase
          .from('putnik_vozac_dodela')
          .select('putnik_id, vozac_id, vozac_ime')
          .eq('datum', datum)
          .eq('grad', gradKey)
          .eq('vreme', vreme);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('⚠️ [PutnikVozacDodela] getDodeleZaDatumGradVreme: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────
  // WRITE
  // ─────────────────────────────────────────────────────────────

  /// Dodeli vozača putniku za određeni datum+grad+vreme
  Future<void> dodelVozaca({
    required String putnikId,
    required String vozacIme,
    String? vozacId,
    required String datum,
    required String grad,
    required String vreme,
  }) async {
    final gradKey = _normalizeGrad(grad);
    final vremeKey = _normalizeVreme(vreme);

    try {
      await _supabase.from('putnik_vozac_dodela').upsert({
        'putnik_id': putnikId,
        'vozac_id': vozacId,
        'vozac_ime': vozacIme,
        'datum': datum,
        'grad': gradKey,
        'vreme': vremeKey,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'putnik_id,datum,grad');

      // Ažuriraj cache
      final key = '$putnikId|$datum|$gradKey';
      _cache[key] = vozacIme;
      _changesController.add(null);

      debugPrint('✅ [PutnikVozacDodela] Dodeljen $vozacIme → putnik $putnikId ($datum, $gradKey)');
    } catch (e) {
      debugPrint('❌ [PutnikVozacDodela] dodelVozaca: $e');
      rethrow;
    }
  }

  /// Ukloni dodelu vozača za putnika
  Future<void> ukloniDodelu({
    required String putnikId,
    required String datum,
    required String grad,
  }) async {
    final gradKey = _normalizeGrad(grad);
    try {
      await _supabase
          .from('putnik_vozac_dodela')
          .delete()
          .eq('putnik_id', putnikId)
          .eq('datum', datum)
          .eq('grad', gradKey);

      final key = '$putnikId|$datum|$gradKey';
      _cache.remove(key);
      _changesController.add(null);
    } catch (e) {
      debugPrint('❌ [PutnikVozacDodela] ukloniDodelu: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CACHE & REALTIME
  // ─────────────────────────────────────────────────────────────

  /// Učitaj sve dodele za datum u cache (poziva se pri init/refresh)
  Future<void> loadZaDatum(String datum) async {
    try {
      final response =
          await _supabase.from('putnik_vozac_dodela').select('putnik_id, datum, grad, vozac_ime').eq('datum', datum);

      // Ukloni stare unose za taj datum iz cache-a
      _cache.removeWhere((key, _) => key.contains('|$datum|'));

      for (final row in response) {
        final putnikId = row['putnik_id'] as String;
        final d = (row['datum'] as String).split('T')[0];
        final g = row['grad'] as String;
        final ime = row['vozac_ime'] as String? ?? '';
        if (ime.isNotEmpty) {
          _cache['$putnikId|$d|$g'] = ime;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [PutnikVozacDodela] loadZaDatum: $e');
    }
  }

  /// Pokreni realtime listener
  void setupRealtimeListener() {
    if (_realtimeChannel != null) return;

    _realtimeChannel = _supabase.channel('public:putnik_vozac_dodela');
    _realtimeChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'putnik_vozac_dodela',
          callback: (payload) async {
            debugPrint('📡 [PutnikVozacDodela] Promena detektovana, osvežavam...');
            // Osvezi cache za datum iz promenjenog reda
            final newRecord = payload.newRecord;
            final oldRecord = payload.oldRecord;
            final datum = (newRecord['datum'] ?? oldRecord['datum'])?.toString().split('T')[0];
            if (datum != null) await loadZaDatum(datum);
            _changesController.add(null);
          },
        )
        .subscribe();
  }

  void dispose() {
    if (_realtimeChannel != null) {
      _supabase.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
    _changesController.close();
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────

  String _normalizeGrad(String grad) {
    final lower = grad.toLowerCase();
    if (lower.contains('vr') || lower == 'vs') return 'vs';
    return 'bc';
  }

  String _normalizeVreme(String vreme) {
    final parts = vreme.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) {
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      }
    }
    return vreme;
  }
}

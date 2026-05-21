import 'package:flutter/foundation.dart';
import 'package:gavra_android/models/v3_gorivo.dart';
import 'package:gavra_android/services/realtime/v3_master_realtime_manager.dart';

import 'repositories/v3_gorivo_repository.dart';

class V3GorivoService {
  V3GorivoService._();

  static final V3GorivoRepository _repo = V3GorivoRepository();

  /// Kreira početni red u tabeli `v3_gorivo` ako tabela nema podataka
  static Future<bool> ensureInitialData() async {
    try {
      final existing = await _repo.selectFirst();
      if (existing.isNotEmpty) {
        return true;
      }

      final row = await _repo.insertReturning({
        'kapacitet_litri': 3000,
        'trenutno_stanje_litri': 0,
        'alarm_nivo_litri': 500,
        'brojac_pistolj_litri': 0,
        'cena_po_litru': 0,
        'dug_iznos': 0,
      });

      _upsertCache(row);
      return true;
    } catch (e) {
      debugPrint('[V3GorivoService] ensureInitialData error: $e');
      return false;
    }
  }

  /// Dohvata stanje pumpe iz cache-a (tabela: v3_gorivo)
  static V3PumpaStanje? getStanjeSync() {
    final cache = V3MasterRealtimeManager.instance.gorivoCache;
    if (cache.isEmpty) return null;
    return V3PumpaStanje.fromJson(cache.values.first);
  }

  /// Dohvata rezervoar iz cache-a (tabela: v3_gorivo)
  static V3PumpaRezervoar? getRezervoarSync() {
    final cache = V3MasterRealtimeManager.instance.gorivoCache;
    if (cache.isEmpty) return null;
    return V3PumpaRezervoar.fromJson(cache.values.first);
  }

  /// Stream koji emituje svaki put kad se gorivo promijeni
  static Stream<V3PumpaStanje?> streamStanje() {
    return V3MasterRealtimeManager.instance.v3StreamFromRevisions(
      tables: ['v3_gorivo'],
      build: getStanjeSync,
    );
  }

  static Stream<V3PumpaRezervoar?> streamRezervoar() {
    return V3MasterRealtimeManager.instance.v3StreamFromRevisions(
      tables: ['v3_gorivo'],
      build: getRezervoarSync,
    );
  }

  /// Ažurira trenutno stanje pumpe u bazi
  static Future<bool> updateStanje(String id, double novoStanje, double noviBrojac) async {
    try {
      final row = await _repo.updateByIdReturning(id, {
        'trenutno_stanje_litri': novoStanje,
        'brojac_pistolj_litri': noviBrojac,
      });
      _upsertCache(row);
      return true;
    } catch (e) {
      debugPrint('[V3GorivoService] updateStanje error: $e');
      return false;
    }
  }

  /// Ažurira trenutni nivo rezervoara u bazi
  static Future<bool> updateRezervoar(String id, double novoLitara) async {
    try {
      final row = await _repo.updateByIdReturning(id, {
        'trenutno_stanje_litri': novoLitara,
      });
      _upsertCache(row);
      return true;
    } catch (e) {
      debugPrint('[V3GorivoService] updateRezervoar failed for id $id: $e');
      return false;
    }
  }

  /// Ažurira sva polja goriva koja se uređuju iz UI forme
  static Future<bool> updateAllFields({
    required String id,
    required double kapacitetLitri,
    required double alarmNivoLitri,
    required double brojacPistoljLitri,
    required double cenaPoLitru,
    required double dugIznos,
  }) async {
    try {
      final row = await _repo.updateByIdReturning(id, {
        'kapacitet_litri': kapacitetLitri,
        'alarm_nivo_litri': alarmNivoLitri,
        'brojac_pistolj_litri': brojacPistoljLitri,
        'cena_po_litru': cenaPoLitru,
        'dug_iznos': dugIznos,
      });
      _upsertCache(row);
      return true;
    } catch (e) {
      debugPrint('[V3GorivoService] updateAllFields error: $e');
      return false;
    }
  }

  /// Pomoćna metoda za sigurno ažuriranje lokalnog cache-a
  static void _upsertCache(Map<String, dynamic> row) {
    if (row.isEmpty) return;
    V3MasterRealtimeManager.instance.v3UpsertToCache('v3_gorivo', row);
  }
}

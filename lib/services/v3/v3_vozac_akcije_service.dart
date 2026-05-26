import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../models/v3_vozac_akcije.dart';
import '../realtime/v3_master_realtime_manager.dart';
import 'repositories/v3_vozac_akcije_repository.dart';

class V3VozacAkcijeService {
  V3VozacAkcijeService._();
  static const Uuid _uuid = Uuid();
  static final V3VozacAkcijeRepository _repo = V3VozacAkcijeRepository();

  /// Evidentira da je vozač pokupio putnika
  static Future<void> evidentirajPokupio({
    required String vozacId,
    required String vozacIme,
    required String putnikId,
    required String putnikIme,
    required DateTime datum,
    String? evidentiraoBy,
  }) async {
    try {
      final akcija = V3VozacAkcija(
        id: _uuid.v4(),
        vozacId: vozacId,
        vozacIme: vozacIme,
        datum: datum,
        tipAkcije: 'pokupio',
        putnikId: putnikId,
        putnikIme: putnikIme,
        createdAt: DateTime.now(),
        createdBy: evidentiraoBy,
      );

      final row = await _repo.insertReturning(akcija.toJson());
      V3MasterRealtimeManager.instance.v3UpsertToCache('v3_vozac_akcije', row);
      
      debugPrint('[V3VozacAkcijeService] Pokupio evidentiran: $vozacIme -> $putnikIme');
    } catch (e) {
      debugPrint('[V3VozacAkcijeService] Greška pri evidentiranju pokupio: $e');
      rethrow;
    }
  }

  /// Evidentira naplatu od strane vozača
  static Future<void> evidentirajNaplata({
    required String vozacId,
    required String vozacIme,
    required String putnikId,
    required String putnikIme,
    required double iznos,
    required DateTime datum,
    String? evidentiraoBy,
  }) async {
    try {
      if (iznos <= 0) {
        throw ArgumentError('Iznos mora biti veći od 0');
      }

      final akcija = V3VozacAkcija(
        id: _uuid.v4(),
        vozacId: vozacId,
        vozacIme: vozacIme,
        datum: datum,
        tipAkcije: 'naplata',
        putnikId: putnikId,
        putnikIme: putnikIme,
        iznos: iznos,
        createdAt: DateTime.now(),
        createdBy: evidentiraoBy,
      );

      final row = await _repo.insertReturning(akcija.toJson());
      V3MasterRealtimeManager.instance.v3UpsertToCache('v3_vozac_akcije', row);
      
      debugPrint('[V3VozacAkcijeService] Naplata evidentirana: $vozacIme <- $putnikIme (${iznos.toStringAsFixed(0)} din)');
    } catch (e) {
      debugPrint('[V3VozacAkcijeService] Greška pri evidentiranju naplate: $e');
      rethrow;
    }
  }

  /// Vraća sve akcije za vozača u određenom danu
  static List<V3VozacAkcija> getAkcijeZaVozacaDan({
    required String vozacId,
    required DateTime dan,
  }) {
    try {
      final cache = V3MasterRealtimeManager.instance.getCache('v3_vozac_akcije').values;
      final targetDay = DateTime(dan.year, dan.month, dan.day);
      
      final akcije = cache.where((row) {
        final rVozacId = row['vozac_id']?.toString() ?? '';
        if (rVozacId != vozacId) return false;
        
        final datum = DateTime.tryParse(row['datum']?.toString() ?? '');
        if (datum == null) return false;
        
        return datum.year == targetDay.year && 
               datum.month == targetDay.month && 
               datum.day == targetDay.day;
      }).map((row) => V3VozacAkcija.fromJson(row)).toList();

      // Sortiraj po datumu (najnovije prvo)
      akcije.sort((a, b) => b.datum.compareTo(a.datum));
      
      return akcije;
    } catch (e) {
      debugPrint('[V3VozacAkcijeService] Greška pri učitavanju akcija: $e');
      return [];
    }
  }

  /// Vraća samo naplate za vozača u određenom danu
  static List<V3VozacAkcija> getNaplataZaVozacaDan({
    required String vozacId,
    required DateTime dan,
  }) {
    return getAkcijeZaVozacaDan(vozacId: vozacId, dan: dan)
        .where((akcija) => akcija.tipAkcije == 'naplata')
        .toList();
  }

  /// Vraća samo pokupljene putnike za vozača u određenom danu
  static List<V3VozacAkcija> getPokupioZaVozacaDan({
    required String vozacId,
    required DateTime dan,
  }) {
    return getAkcijeZaVozacaDan(vozacId: vozacId, dan: dan)
        .where((akcija) => akcija.tipAkcije == 'pokupio')
        .toList();
  }

  /// Računa ukupan iznos naplata za vozača u određenom danu
  static double getUkupanIznosNaplata({
    required String vozacId,
    required DateTime dan,
  }) {
    final naplate = getNaplataZaVozacaDan(vozacId: vozacId, dan: dan);
    return naplate.fold(0.0, (sum, naplata) => sum + naplata.iznos);
  }

  /// Vraća broj pokupljenih putnika za vozača u određenom danu
  static int getBrojPokupljenih({
    required String vozacId,
    required DateTime dan,
  }) {
    final pokupio = getPokupioZaVozacaDan(vozacId: vozacId, dan: dan);
    return pokupio.length;
  }

  /// Vraća broj naplata za vozača u određenom danu
  static int getBrojNaplata({
    required String vozacId,
    required DateTime dan,
  }) {
    final naplate = getNaplataZaVozacaDan(vozacId: vozacId, dan: dan);
    return naplate.length;
  }

  /// Vraća sumarno izvešće za vozača u određenom danu
  static ({
    int brojPokupljenih,
    int brojNaplata,
    double ukupanIznos,
    List<V3VozacAkcija> pokupio,
    List<V3VozacAkcija> naplate,
  }) getIzvestajZaVozacaDan({
    required String vozacId,
    required DateTime dan,
  }) {
    final pokupio = getPokupioZaVozacaDan(vozacId: vozacId, dan: dan);
    final naplate = getNaplataZaVozacaDan(vozacId: vozacId, dan: dan);
    final ukupanIznos = naplate.fold(0.0, (sum, naplata) => sum + naplata.iznos);

    return (
      brojPokupljenih: pokupio.length,
      brojNaplata: naplate.length,
      ukupanIznos: ukupanIznos,
      pokupio: pokupio,
      naplate: naplate,
    );
  }

  /// Stream za praćenje naplata vozača u određenom danu
  static Stream<List<V3VozacAkcija>> streamNaplataZaVozacaDan({
    required String vozacId,
    required DateTime dan,
  }) {
    return V3MasterRealtimeManager.instance.v3StreamFromRevisions(
      tables: ['v3_vozac_akcije'],
      build: () => getNaplataZaVozacaDan(vozacId: vozacId, dan: dan),
    );
  }

  /// Stream za praćenje svih akcija vozača u određenom danu
  static Stream<List<V3VozacAkcija>> streamAkcijeZaVozacaDan({
    required String vozacId,
    required DateTime dan,
  }) {
    return V3MasterRealtimeManager.instance.v3StreamFromRevisions(
      tables: ['v3_vozac_akcije'],
      build: () => getAkcijeZaVozacaDan(vozacId: vozacId, dan: dan),
    );
  }
}

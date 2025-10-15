import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'vozac_mapping_service.dart';

/// Servis za upravljanje kusur-om vozača u bazi podataka
class KusurService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Stream controller za real-time ažuriranje kusur kocki
  static final StreamController<Map<String, double>> _kusurController =
      StreamController<Map<String, double>>.broadcast();

  /// Dobij kusur za određenog vozača iz baze
  static Future<double> getKusurForVozac(String vozacIme) async {
    try {
      // Mapiranje ime -> UUID
      final vozacUuid = await VozacMappingService.getVozacUuid(vozacIme);
      if (vozacUuid == null) {
        return 0.0;
      }

      final response = await _supabase.from('vozaci').select('kusur').eq('id', vozacUuid).maybeSingle();

      if (response != null && response['kusur'] != null) {
        return (response['kusur'] as num).toDouble();
      }

      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// Ažuriraj kusur za određenog vozača u bazi
  static Future<bool> updateKusurForVozac(String vozacIme, double noviKusur) async {
    try {
      // Mapiranje ime -> UUID
      final vozacUuid = await VozacMappingService.getVozacUuid(vozacIme);
      if (vozacUuid == null) {
        return false;
      }

      await _supabase.from('vozaci').update({'kusur': noviKusur}).eq('id', vozacUuid);

      // Emituj ažuriranje preko stream-a
      _emitKusurUpdate(vozacIme, noviKusur);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Stream za real-time praćenje kusur-a određenog vozača
  static Stream<double> streamKusurForVozac(String vozacIme) async* {
    // Odmah pošalji trenutnu vrednost
    final trenutniKusur = await getKusurForVozac(vozacIme);
    yield trenutniKusur;

    // Zatim slušaj za ažuriranja
    await for (final kusurMapa in _kusurController.stream) {
      if (kusurMapa.containsKey(vozacIme)) {
        yield kusurMapa[vozacIme]!;
      }
    }
  }

  /// Dobij kusur za sve vozače odjednom
  static Future<Map<String, double>> getKusurSvihVozaca() async {
    try {
      final response = await _supabase.from('vozaci').select('id, ime, kusur');

      final Map<String, double> rezultat = {};

      for (final row in response) {
        final ime = row['ime'] as String;
        final kusur = (row['kusur'] as num?)?.toDouble() ?? 0.0;
        rezultat[ime] = kusur;
      }

      return rezultat;
    } catch (e) {
      return {};
    }
  }

  /// Privatni helper za emitovanje ažuriranja
  static void _emitKusurUpdate(String vozacIme, double noviKusur) {
    if (!_kusurController.isClosed) {
      _kusurController.add({vozacIme: noviKusur});
    }
  }

  /// Resetuj kusur za vozača na 0
  static Future<bool> resetKusurForVozac(String vozacIme) async {
    return await updateKusurForVozac(vozacIme, 0.0);
  }

  /// Dodaj iznos u kusur vozača (increment)
  static Future<bool> dodajUKusur(String vozacIme, double iznos) async {
    final trenutniKusur = await getKusurForVozac(vozacIme);
    final noviKusur = trenutniKusur + iznos;
    return await updateKusurForVozac(vozacIme, noviKusur);
  }

  /// Oduzmi iznos iz kusur vozača (decrement)
  static Future<bool> oduzmiIzKusur(String vozacIme, double iznos) async {
    final trenutniKusur = await getKusurForVozac(vozacIme);
    final noviKusur = (trenutniKusur - iznos).clamp(0.0, double.infinity);
    return await updateKusurForVozac(vozacIme, noviKusur);
  }

  /// Zatvori stream controller
  static void dispose() {
    _kusurController.close();
  }
}





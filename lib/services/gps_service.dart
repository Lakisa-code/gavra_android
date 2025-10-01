import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GpsService {
  static final Logger _logger = Logger();

  /// Konvertuje ime vozača u UUID iz vozaci tabele
  static Future<String?> _getVozacUuid(String vozacIme) async {
    try {
      final supabase = Supabase.instance.client;
      // Avoid using `.single()` because it throws when 0 or multiple rows are
      // returned. Instead fetch the rows and handle empty/multiple results
      // gracefully.
      final dynamic response =
          await supabase.from('vozaci').select('id').eq('ime', vozacIme);

      // The SDK normally returns a List for select() without .single().
      if (response is List) {
        if (response.isEmpty) {
          _logger.w('⚠️ Nije pronađen vozač sa imenom: $vozacIme');
          // Nemamo permisiju za automatsko kreiranje redova sa anon ključem
          // (PostgrestException: row-level security). Ne pokušavamo više
          // automatsku registraciju sa klijentske strane iz sigurnosnih razloga.
          _logger.i(
              'ℹ️ RLS policy on table `vozaci` preventing anonymous inserts.\n'
              'Uputstvo: kreirajte vozača ručno u Supabase dashboard-u,\n'
              'ili iz backend servisa koji koristi SERVICE_ROLE key za administrativne operacije.');
          return null;
        }
        if (response.length > 1) {
          _logger.w(
              '⚠️ Pronađeno više vozača sa imenom "$vozacIme"; koristiću prvi match.');
        }
        final first = response.first;
        if (first is Map<String, dynamic>) {
          final idVal = first['id'];
          return idVal == null ? null : idVal.toString();
        }
        _logger
            .w('⚠️ Neočekivan format reda iz Supabase: ${first.runtimeType}');
        return null;
      }

      // If SDK returned a Map (single row), handle that as well
      if (response is Map<String, dynamic>) {
        final idVal = response['id'];
        return idVal == null ? null : idVal.toString();
      }

      _logger.w(
          '⚠️ Neočekivan tip odgovora prilikom traženja vozaca: ${response.runtimeType}');
      return null;
    } catch (e) {
      _logger.e('❌ Greška pri dobijanju UUID vozača $vozacIme: $e');
      return null;
    }
  }

  static Future<void> sendCurrentLocation({required String vozacId}) async {
    try {
      _logger.i('🔄 Početak slanja GPS lokacije za vozača: $vozacId');

      // Konvertuj ime vozača u UUID ako je potrebno
      String? vozacUuid = vozacId;
      if (!RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
          .hasMatch(vozacId)) {
        // Nije UUID, pokušaj konverziju
        vozacUuid = await _getVozacUuid(vozacId);
        if (vozacUuid == null) {
          throw Exception('Nije moguće naći UUID za vozača: $vozacId');
        }
        _logger.i('✅ Konvertovano ime vozača $vozacId u UUID: $vozacUuid');
      }

      // Provera dozvola
      LocationPermission permission = await Geolocator.checkPermission();
      _logger.d('🔍 Provera dozvola: $permission');

      if (permission == LocationPermission.denied) {
        _logger.w('⚠️ Dozvola odbijena, zahtevam ponovo...');
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('GPS dozvola odbijena');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('GPS dozvola trajno odbijena');
      }

      // Uzimanje lokacije
      _logger.i('📍 Dobijanje trenutne lokacije...');
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _logger.i(
          '✅ Lokacija dobijena: ${position.latitude}, ${position.longitude}');

      // Slanje u Supabase
      _logger.i('📤 Slanje lokacije u Supabase...');
      final supabase = Supabase.instance.client;
      await supabase.from('gps_lokacije').insert({
        'vozac_id': vozacUuid, // koristi konvertovani UUID
        'latitude': position.latitude,
        'longitude': position.longitude,
        'brzina': position.speed * 3.6, // pretvori m/s u km/h
        'pravac': position.heading,
        'tacnost': position.accuracy,
        // vreme će se automatski postaviti na NOW()
      });
      _logger.i('✅ Lokacija uspešno poslata u Supabase');
    } catch (e) {
      _logger.e('❌ GPS slanje greška: $e');
    }
  }
}

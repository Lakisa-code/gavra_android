import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'vozac_mapping_service.dart';

class GpsService {
  /// Konvertuje ime vozača u UUID iz vozaci tabele sa poboljšanim error handling-om
  static Future<String?> _getVozacUuid(String vozacIme) async {
    try {
      final supabase = Supabase.instance.client;

      // Prvo proverava cache iz VozacMappingService
      final cachedUuid = VozacMappingService.getVozacUuidSync(vozacIme);
      if (cachedUuid != null) {
        // Logger removed
        return cachedUuid;
      }

      // Logger removed

      // Avoid using `.single()` because it throws when 0 or multiple rows are
      // returned. Instead fetch the rows and handle empty/multiple results
      // gracefully.
      final dynamic response = await supabase.from('vozaci').select('id').eq('ime', vozacIme);

      // The SDK normally returns a List for select() without .single().
      if (response is List) {
        if (response.isEmpty) {
          // Logger removed

          // Pokušaj da refreshuj cache i ponovo potraži
          await VozacMappingService.refreshMapping();
          final refreshedUuid = VozacMappingService.getVozacUuidSync(vozacIme);
          if (refreshedUuid != null) {
            return refreshedUuid;
          }

          // Nemamo permisiju za automatsko kreiranje redova sa anon ključem
          // (PostgrestException: row-level security). Ne pokušavamo više
          // automatsku registraciju sa klijentske strane iz sigurnosnih razloga.

          return null;
        }
        if (response.length > 1) {
          // Multiple matches found, using first one
        }
        final first = response.first;
        if (first is Map<String, dynamic>) {
          final uuid = first['id']?.toString();
          // Logger removed
          return uuid;
        }
        // Logger removed;
        return null;
      }

      // If SDK returned a Map (single row), handle that as well
      if (response is Map<String, dynamic>) {
        final uuid = response['id']?.toString();
        // Logger removed
        return uuid;
      }

      return null;
    } on PostgrestException catch (e) {
      if (e.message.contains('row-level security')) {
        // Logger removed;
        // Pokušaj fallback sa cache
        final fallbackUuid = VozacMappingService.getVozacUuidSync(vozacIme);
        if (fallbackUuid != null) {
          return fallbackUuid;
        }
      } else {}
      return null;
    } catch (e) {
      // Logger removed
      // Pokušaj fallback sa cache
      final fallbackUuid = VozacMappingService.getVozacUuidSync(vozacIme);
      if (fallbackUuid != null) {
        return fallbackUuid;
      }
      return null;
    }
  }

  static Future<void> sendCurrentLocation({
    required String vozacId,
    required String voziloId,
  }) async {
    try {
      // Logger removed

      // Konvertuj ime vozača u UUID ako je potrebno
      String? vozacUuid = vozacId;
      if (!RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      ).hasMatch(vozacId)) {
        // Nije UUID, pokušaj konverziju
        vozacUuid = await _getVozacUuid(vozacId);
        if (vozacUuid == null) {
          throw Exception('Nije moguće naći UUID za vozača: $vozacId');
        }
        // Logger removed
      }

      // Provera dozvola
      LocationPermission permission = await Geolocator.checkPermission();
      // Logger removed

      if (permission == LocationPermission.denied) {
        // Logger removed
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('GPS dozvola odbijena');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('GPS dozvola trajno odbijena');
      }

      // Uzimanje lokacije
      // Logger removed
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Slanje u Supabase
      // Logger removed
      final supabase = Supabase.instance.client;
      await supabase.from('gps_lokacije').insert({
        'vozac_id': vozacUuid, // koristi konvertovani UUID
        'vozilo_id': voziloId, // obavezno vozilo
        'latitude': position.latitude,
        'longitude': position.longitude,
        'brzina': position.speed * 3.6, // pretvori m/s u km/h
        'pravac': position.heading,
        // 'tacnost': position.accuracy, // UKLONJENO - ne postoji u modelu
        // vreme će se automatski postaviti na NOW()
      });
      // Logger removed
    } catch (e) {
      // Logger removed
    }
  }
}

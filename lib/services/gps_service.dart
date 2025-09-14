import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GpsService {
  static final Logger _logger = Logger();

  static Future<void> sendCurrentLocation({required String vozacId}) async {
    try {
      _logger.i('🔄 Početak slanja GPS lokacije za vozača: $vozacId');

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
        'name': vozacId, // koristi ime vozača umesto vozac_id
        'lat': position.latitude,
        'lng': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _logger.i('✅ Lokacija uspešno poslata u Supabase');
    } catch (e) {
      _logger.e('❌ GPS slanje greška: $e');
    }
  }
}

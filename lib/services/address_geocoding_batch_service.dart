import 'package:gavra_android/services/geocoding_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servis za masovno dodavanje GPS koordinata u adrese tabelu
/// Koristi GeocodingService i automatski ažurira bazu podataka
class AddressGeocodingBatchService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Dodaj GPS koordinate za sve adrese bez koordinata
  static Future<void> geocodeAllMissingAddresses() async {
    try {
      print('🌍 Započinje batch geocoding svih adresa...');

      // 1. Uzmi sve adrese bez koordinata
      final response =
          await _supabase.from('adrese').select('id, naziv, grad, koordinate').isFilter('koordinate', null);

      final List<dynamic> adrese = response as List<dynamic>;
      print('📍 Pronađeno ${adrese.length} adresa bez koordinata');

      if (adrese.isEmpty) {
        print('✅ Sve adrese već imaju koordinate!');
        return;
      }

      int uspesne = 0;
      int neuspesne = 0;

      // 2. Geocoding za svaku adresu
      for (int i = 0; i < adrese.length; i++) {
        final adresa = adrese[i];
        final id = adresa['id'];
        final naziv = adresa['naziv'];
        final grad = adresa['grad'];

        print('🔍 Geocoding ${i + 1}/${adrese.length}: $naziv, $grad');

        // Koristi postojeći GeocodingService
        final koordinateString = await GeocodingService.getKoordinateZaAdresu(
          grad?.toString() ?? '',
          naziv?.toString() ?? '',
        );

        if (koordinateString != null) {
          // Parse koordinate iz "lat,lng" formata
          final parts = koordinateString.split(',');
          if (parts.length == 2) {
            final lat = double.tryParse(parts[0]);
            final lng = double.tryParse(parts[1]);

            if (lat != null && lng != null) {
              // Sačuvaj u bazu kao JSONB
              await _supabase.from('adrese').update({
                'koordinate': {'lat': lat, 'lng': lng},
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('id', id.toString());

              uspesne++;
              print('✅ Uspešno: $naziv → $lat, $lng');
            } else {
              neuspesne++;
              print('❌ Neispravne koordinate: $naziv → $koordinateString');
            }
          } else {
            neuspesne++;
            print('❌ Neispravne koordinate format: $naziv → $koordinateString');
          }
        } else {
          neuspesne++;
          print('❌ Geocoding failed: $naziv, $grad');
        }

        // Poštuj rate limiting - 1 sekunda između zahteva
        if (i < adrese.length - 1) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }

      print('\n📊 BATCH GEOCODING ZAVRŠEN:');
      print('✅ Uspešne: $uspesne');
      print('❌ Neuspešne: $neuspesne');
      print('📍 Ukupno: ${uspesne + neuspesne}');
    } catch (e) {
      print('❌ Greška tokom batch geocoding: $e');
      rethrow;
    }
  }

  /// Proverava status geocoding za sve adrese
  static Future<Map<String, dynamic>> getGeocodingStatus() async {
    try {
      final response = await _supabase.from('adrese').select('id, naziv, grad, koordinate');

      final List<dynamic> adrese = response as List<dynamic>;

      int saKoordinatama = 0;
      int bezKoordinata = 0;
      Map<String, int> statusPoGradovima = {};

      for (final adresa in adrese) {
        final grad = adresa['grad']?.toString() ?? 'Nepoznat';
        final koordinate = adresa['koordinate'];

        if (koordinate != null && koordinate is Map) {
          saKoordinatama++;
          statusPoGradovima[grad] = (statusPoGradovima[grad] ?? 0) + 1;
        } else {
          bezKoordinata++;
        }
      }

      return {
        'ukupno_adresa': adrese.length,
        'sa_koordinatama': saKoordinatama,
        'bez_koordinata': bezKoordinata,
        'procenat_kompletiran': adrese.isEmpty ? 0 : (saKoordinatama / adrese.length * 100).round(),
        'status_po_gradovima': statusPoGradovima,
      };
    } catch (e) {
      print('❌ Greška pri dobijanju geocoding statusa: $e');
      return {
        'error': e.toString(),
      };
    }
  }

  /// Ponovo pokušaj geocoding samo za neuspešne adrese
  static Future<void> retryFailedGeocoding() async {
    print('🔄 Ponavljam geocoding za neuspešne adrese...');
    await geocodeAllMissingAddresses();
  }

  /// Briše sve GPS koordinate (za testing)
  static Future<void> clearAllCoordinates() async {
    try {
      print('🗑️ Brišem sve GPS koordinate...');

      await _supabase.from('adrese').update({
        'koordinate': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).neq('id', ''); // Update sve adrese

      print('✅ Sve koordinate obrisane');
    } catch (e) {
      print('❌ Greška pri brisanju koordinata: $e');
      rethrow;
    }
  }
}

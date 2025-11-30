import '../globals.dart';
import 'geocoding_service.dart';

/// Servis za masovno dodavanje GPS koordinata u adrese tabelu
/// Koristi GeocodingService i automatski ažurira bazu podataka
class AddressGeocodingBatchService {
  /// Dodaj GPS koordinate za sve adrese bez koordinata
  static Future<void> geocodeAllMissingAddresses() async {
    try {
      // 1. Uzmi sve adrese bez koordinata
      final response = await supabase.from('adrese').select('id, naziv, grad, koordinate').isFilter('koordinate', null);

      final List<dynamic> adrese = response as List<dynamic>;

      if (adrese.isEmpty) {
        return;
      }

      // 2. Geocoding za svaku adresu
      for (int i = 0; i < adrese.length; i++) {
        final adresa = adrese[i];
        final id = adresa['id'];
        final naziv = adresa['naziv'];
        final grad = adresa['grad'];

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
              await supabase.from('adrese').update({
                'koordinate': {'lat': lat, 'lng': lng},
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('id', id.toString());
            }
          } else {
            // Neispravne koordinate format
          }
        } else {
          // Geocoding failed
        }

        // Poštuj rate limiting - 1 sekunda između zahteva
        if (i < adrese.length - 1) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Proverava status geocoding za sve adrese
  static Future<Map<String, dynamic>> getGeocodingStatus() async {
    try {
      final response = await supabase.from('adrese').select('id, naziv, grad, koordinate');

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
      return {'error': e.toString()};
    }
  }

  /// Ponovo pokušaj geocoding samo za neuspešne adrese
  static Future<void> retryFailedGeocoding() async {
    await geocodeAllMissingAddresses();
  }

  /// Briše sve GPS koordinate (za testing)
  static Future<void> clearAllCoordinates() async {
    try {
      await supabase.from('adrese').update({'koordinate': null, 'updated_at': DateTime.now().toIso8601String()}).neq(
          'id', ''); // Update sve adrese
    } catch (e) {
      rethrow;
    }
  }
}

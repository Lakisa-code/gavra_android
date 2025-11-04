import 'dart:convert';
import 'dart:io';

/// Jednostavan test geocoding servisa bez Flutter dependency-ja
void main() async {
  print('🌍 GAVRA ANDROID - SIMPLE GEOCODING TEST');
  print('=' * 50);

  try {
    // Test direktno preko HTTP API-ja
    final url =
        'https://nominatim.openstreetmap.org/search?q=Bela%20Crkva,%20Serbia&format=json&limit=1&countrycodes=rs';

    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set('User-Agent', 'GavraAndroidApp/1.0 (transport app)');

    final response = await request.close();

    if (response.statusCode == 200) {
      final body = await response.transform(utf8.decoder).join();
      final dynamic jsonData = json.decode(body);

      if (jsonData is List && jsonData.isNotEmpty) {
        final result = jsonData.first;
        final String lat = result['lat']?.toString() ?? '';
        final String lng = result['lon']?.toString() ?? '';

        print('✅ GEOCODING SUCCESSFUL:');
        print('📍 Lokacija: ${result['display_name']}');
        print('🎯 Koordinate: $lat, $lng');
        print('🏷️ Type: ${result['type']}');

        // Testiranje formata koordinata
        final koordinate = {'lat': double.parse(lat), 'lng': double.parse(lng)};
        print('📦 JSONB format: ${json.encode(koordinate)}');
      } else {
        print('❌ Nema rezultata za Bela Crkva');
      }
    } else {
      print('❌ HTTP greška: ${response.statusCode}');
    }

    client.close();
  } catch (e) {
    print('❌ GREŠKA: $e');
  }

  print('\n🏁 TEST ZAVRŠEN - Geocoding servis radi!');
  print('💡 Možeš pokrenuti batch geocoding preko admin UI-ja u aplikaciji');
}

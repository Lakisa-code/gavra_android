// 🧪 HUAWEI API TEST SCRIPT
// Testira koji Huawei Map Kit API-ji rade sa tvojim API ključem
//
// Pokreni sa: dart run scripts/test_huawei_api.dart

import 'dart:convert';

import 'package:http/http.dart' as http;

// API ključ iz Credentials konzole (REST API key)
const String apiKeyRest =
    'DgEDAK2okuh7rK4SyckpwfSFsceX4arhDmzU1j/W6iei+orqVCWLO1K/r8wY2pS3FGcByd7xvHOkXUveVwM4jZ7tjx2ZTvMqtSeCtA==';

// API ključ iz AGConnect (agconnect-services.json)
const String apiKeyAgc =
    'DgEDAPGlpFMHrZfl5fOXaDtrHVPjJcOxyaeORpHR6F+FVPViEIuLxomXbW4gwsuFGd4/fG6qsTCRyc9pcXz7beT8KkEMfGKNf8biew==';

// Test koordinate - Bela Crkva
const double testLat1 = 44.8989;
const double testLng1 = 21.4167;

// Test koordinate - Vršac
const double testLat2 = 45.1167;
const double testLng2 = 21.3000;

void main() async {
  print('');
  print('🧪 ═══════════════════════════════════════════════════════════');
  print('🧪 HUAWEI MAP KIT API TEST (ISPRAVNI URL-ovi iz HMS Demo)');
  print('🧪 ═══════════════════════════════════════════════════════════');

  // Test sa oba API ključa
  await testRoutingWithBothKeys();

  print('');
  print('🧪 ═══════════════════════════════════════════════════════════');
  print('🧪 TESTIRANJE ZAVRŠENO');
  print('🧪 ═══════════════════════════════════════════════════════════');
}

/// Test Routing API sa oba ključa
Future<void> testRoutingWithBothKeys() async {
  final apiKeys = {
    'REST (Credentials)': apiKeyRest,
    'AGC (agconnect-services.json)': apiKeyAgc,
  };

  final endpoints = [
    'https://mapapi.cloud.huawei.com/mapApi/v1/routeService/driving',
    'https://mapapi.cloud.huawei.com/mapApi/v1/routeService/walking',
  ];

  for (final keyEntry in apiKeys.entries) {
    final keyName = keyEntry.key;
    final apiKey = keyEntry.value;
    final encodedKey = Uri.encodeComponent(apiKey);

    print('');
    print('🔑 ═══ Testiram: $keyName ═══');

    for (final baseUrl in endpoints) {
      final endpointName = baseUrl.split('/').last;

      try {
        final url = Uri.parse('$baseUrl?key=$encodedKey');

        final body = json.encode({
          'origin': {'lat': testLat1, 'lng': testLng1},
          'destination': {'lat': testLat2, 'lng': testLng2},
        });

        print('');
        print('   📍 POST /$endpointName');

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json; charset=utf-8'},
              body: body,
            )
            .timeout(Duration(seconds: 10));

        print('   Status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;

          if (data['returnCode'] == '0') {
            final routes = data['routes'] as List?;
            if (routes != null && routes.isNotEmpty) {
              final route = routes[0] as Map<String, dynamic>;
              final paths = route['paths'] as List?;
              if (paths != null && paths.isNotEmpty) {
                final path = paths[0] as Map<String, dynamic>;
                print('   ✅ USPEH! Distanca: ${path['distance']}m, Vreme: ${path['duration']}s');
                print('');
                print('   🎉 PRONAĐEN RADNI API!');
                print('   🔑 Ključ: $keyName');
                print('   🌐 Endpoint: $baseUrl');
                return;
              }
            }
          } else {
            print('   ⚠️ returnCode: ${data['returnCode']}');
            print('   ⚠️ returnDesc: ${data['returnDesc'] ?? 'N/A'}');
          }
        } else {
          final respBody = response.body;
          if (respBody.isNotEmpty) {
            try {
              final data = json.decode(respBody) as Map<String, dynamic>;
              print('   ❌ returnCode: ${data['returnCode']}');
              print('   ❌ returnDesc: ${data['returnDesc'] ?? 'N/A'}');
            } catch (_) {
              print('   ❌ Body: ${respBody.length > 200 ? '${respBody.substring(0, 200)}...' : respBody}');
            }
          }
        }
      } catch (e) {
        print('   ❌ Error: $e');
      }
    }
  }

  print('');
  print('❌ ═══════════════════════════════════════════════════════════');
  print('❌ NIJEDAN API KLJUČ NE RADI SA ROUTING SERVISOM');
  print('❌ ═══════════════════════════════════════════════════════════');
  print('');
  print('Mogući razlozi:');
  print('  1. Route Planning API nije aktiviran u AppGallery Connect');
  print('  2. Potreban je Directions API koji zahteva Navi Kit (SDK only)');
  print('  3. API ključ nema dozvolu za ovaj servis');
  print('');
  print('Preporuka: Nastavi sa OSRM + Nominatim (besplatno i radi!)');
}

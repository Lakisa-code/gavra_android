import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Hardcoded addresses from DB for Vršac (Verified via SQL)
  final List<Map<String, dynamic>> addresses = [
    {"naziv": "Bolnica", "grad": "Vršac", "db_lat": 45.121788, "db_lng": 21.306824},
    {"naziv": "Dimitrija Tucovica 93", "grad": "Vršac", "db_lat": 45.112092, "db_lng": 21.307598},
    {"naziv": "Dis", "grad": "Vršac", "db_lat": 45.1104438, "db_lng": 21.2978117},
    {"naziv": "Fresenius", "grad": "Vršac", "db_lat": 45.102364, "db_lng": 21.281384},
    {"naziv": "Gimnazija pekara (Škola)", "grad": "Vršac", "db_lat": 45.116993, "db_lng": 21.305091},
    {"naziv": "Hemofarm", "grad": "Vršac", "db_lat": 45.1011635, "db_lng": 21.2773419},
    {"naziv": "Centar Milenijum", "grad": "Vršac", "db_lat": 45.117974, "db_lng": 21.31086},
    {"naziv": "Prima pumpa (MOL)", "grad": "Vršac", "db_lat": 45.1027318, "db_lng": 21.2985089},
    {"naziv": "Maxi-Lidl", "grad": "Vršac", "db_lat": 45.109867, "db_lng": 21.285514},
    {"naziv": "Psihijatrija", "grad": "Vršac", "db_lat": 45.124575, "db_lng": 21.312003},
    {"naziv": "Sud", "grad": "Vršac", "db_lat": 45.117003, "db_lng": 21.300345},
  ];

  // Haversine distance in meters
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    const c = cos;
    final a = 0.5 - c((lat2 - lat1) * p) / 2 + c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000;
  }

  Future<Map<String, dynamic>> checkPhoton(String grad, String adresa) async {
    try {
      final query = '$adresa, $grad';
      const String bbox = '&bbox=18.82,41.85,23.01,46.19';
      final url = 'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&limit=1$bbox';
      final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'GavraAndroid/1.0'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        if (features.isNotEmpty) {
          final coords = features[0]['geometry']['coordinates'];
          return {'found': true, 'lat': coords[1], 'lng': coords[0]};
        }
      }
    } catch (_) {}
    return {'found': false};
  }

  test('Verify Vršac DB Addresses', () async {
    print('\n🔍 PROVERA ADRESA IZ BAZE (VRŠAC) 🔍\n');
    print(
        '${"ADRESA".padRight(25)} | ${"DB STATUS".padRight(15)} | ${"PHOTON".padRight(15)} | ${"RAZLIKA (m)".padRight(15)}');
    print('-' * 80);

    for (final item in addresses) {
      final grad = item['grad'];
      final naziv = item['naziv'];
      final dbLat = item['db_lat'];
      final dbLng = item['db_lng'];

      final photonRes = await checkPhoton(grad, naziv);
      await Future.delayed(const Duration(milliseconds: 300)); // Rate limit

      String dbStatus = (dbLat != null) ? "✅ Ima" : "⚠️ Nema";
      String photonStatus = photonRes['found'] ? "✅ Našao" : "❌ Nije";
      String diffText = "-";

      if (dbLat != null && photonRes['found']) {
        final dist = calculateDistance(dbLat, dbLng, photonRes['lat'], photonRes['lng']);
        diffText = '${dist.toStringAsFixed(0)}m';
        if (dist > 200) {
          diffText += " ❗";
        } else {
          diffText += " ✅";
        }
      } else if (dbLat == null && photonRes['found']) {
        diffText = "🆕 PREDLOG";
      }

      print(
          '${naziv.toString().padRight(25)} | ${dbStatus.padRight(15)} | ${photonStatus.padRight(15)} | ${diffText.padRight(15)}');

      if (dbLat == null && photonRes['found']) {
        print('   >>> PREDLOG KOORDINATA: ${photonRes['lat']}, ${photonRes['lng']}');
      }
    }
    print('-' * 80);
  });
}

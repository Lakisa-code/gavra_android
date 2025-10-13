import 'dart:convert';
import 'dart:io';

void main() async {
  final client = HttpClient();

  try {
    // Supabase detalji
    final baseUrl = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
    final apiKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTg3NzU0OTUsImV4cCI6MjAzNDM1MTQ5NX0.V58kOa-t1an8BFxJTC0SYNPgKVQnDF1TQ8uRTIknIC0';

    print('=== PROVERA SUPABASE BAZE ZA DANA 2025-10-13 ===\n');

    // Danas datum
    final today = '2025-10-13';
    final bojanId = '6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e';

    print('Provera za vozača: $bojanId');
    print('Datum: $today\n');

    // 1. Proveri putovanja_istorija tabelu
    await checkTable(client, baseUrl, apiKey, 'putovanja_istorija', {
      'datum': today,
      'vozac_id': bojanId,
    });

    // 2. Proveri mesecni_putnici tabelu
    await checkTable(client, baseUrl, apiKey, 'mesecni_putnici', {
      'datum': today,
      'vozac_id': bojanId,
    });

    // 3. Proveri daily_checkins tabelu
    await checkTable(client, baseUrl, apiKey, 'daily_checkins', {
      'datum': today,
      'vozac_id': bojanId,
    });

    // 4. Proveri sve danas za bilo kog vozača
    print('\n=== PROVERA SVIH DANAS UNOSA ===');
    await checkTable(client, baseUrl, apiKey, 'putovanja_istorija', {
      'datum': today,
    });
  } catch (e) {
    print('Greška: $e');
  } finally {
    client.close();
  }
}

Future<void> checkTable(
    HttpClient client, String baseUrl, String apiKey, String table, Map<String, String> filters) async {
  try {
    print('--- Provera tabele: $table ---');

    // Kreiraj URL sa filterima
    String url = '$baseUrl/rest/v1/$table?select=*';

    for (final entry in filters.entries) {
      url += '&${entry.key}=eq.${entry.value}';
    }

    final request = await client.getUrl(Uri.parse(url));
    request.headers.set('apikey', apiKey);
    request.headers.set('Authorization', 'Bearer $apiKey');
    request.headers.set('Content-Type', 'application/json');

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(responseBody);
      print('Broj rezultata: ${data.length}');

      if (data.isNotEmpty) {
        print('Podaci:');
        for (int i = 0; i < data.length && i < 5; i++) {
          final item = data[i];
          print('  - Red ${i + 1}: ${item}');
        }
        if (data.length > 5) {
          print('  ... i još ${data.length - 5} redova');
        }

        // Pokušaj da računaš ukupnu cenu
        double totalCena = 0;
        for (final item in data) {
          if (item['cena'] != null) {
            totalCena += (item['cena'] as num).toDouble();
          }
        }
        if (totalCena > 0) {
          print('UKUPNA CENA: $totalCena RSD');
        }
      } else {
        print('Nema podataka za zadate kriterijume.');
      }
    } else {
      print('Greška HTTP ${response.statusCode}: $responseBody');
    }

    print('');
  } catch (e) {
    print('Greška pri proveri tabele $table: $e\n');
  }
}

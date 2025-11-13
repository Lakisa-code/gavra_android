// 🔍 DEBUG SCRIPT za plaćanja
// Koristi ovaj script za testiranje plaćanja van aplikacije

Future<void> main() async {
  print('🔍 DEBUG PLAĆANJA - Početak testiranja...');

  try {
    // Simuliraj plaćanje
    await testMesecnoPlacanje();
    await testObicnoPlacanje();

    print('✅ SVI TESTOVI USPEŠNI!');
  } catch (e) {
    print('❌ GREŠKA U TESTOVIMA: $e');
  }
}

Future<void> testMesecnoPlacanje() async {
  print('\n📅 TESTIRANJE MESEČNOG PLAĆANJA...');

  try {
    // Test parametri
    final putnikId = 'test-id-123';
    final iznos = 2500.0;
    final vozacIme = 'Bojan';
    final pocetakMeseca = DateTime(2024, 11, 1);
    final krajMeseca = DateTime(2024, 11, 30, 23, 59, 59);

    print('- Putnik ID: $putnikId');
    print('- Iznos: $iznos RSD');
    print('- Vozač: $vozacIme');
    print('- Period: ${pocetakMeseca.toIso8601String()} - ${krajMeseca.toIso8601String()}');

    // Simuliraj UUID validaciju
    final isValidUuid =
        RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(putnikId);
    print('- UUID valid: $isValidUuid');

    // Simuliraj vozac mapping
    final hardcodedMapping = {
      'Bojan': '6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e',
      'Svetlana': '5b379394-084e-1c7d-76bf-fc193a5b6c7d',
      'Bruda': '7d59b5b6-2a4a-3e9f-98e1-1e3b4c7d8e9f',
      'Bilevski': '8e68c6c7-3b8b-4f8a-a9d2-2f4b5c8d9e0f',
    };

    final vozacUuid = hardcodedMapping[vozacIme];
    print('- Vozač UUID: $vozacUuid');

    if (vozacUuid == null) {
      throw Exception('Vozač $vozacIme nema mapirani UUID');
    }

    print('✅ Mesečno plaćanje - validacija OK');
  } catch (e) {
    print('❌ Mesečno plaćanje FAILED: $e');
    rethrow;
  }
}

Future<void> testObicnoPlacanje() async {
  print('\n💵 TESTIRANJE OBIČNOG PLAĆANJA...');

  try {
    // Test parametri
    final putnikId = 'putnik-456';
    final iznos = 150.0;
    final vozacIme = 'Svetlana';

    print('- Putnik ID: $putnikId');
    print('- Iznos: $iznos RSD');
    print('- Vozač: $vozacIme');

    // Validacija ID-a
    if (putnikId.isEmpty) {
      throw Exception('Putnik ID je prazan');
    }

    if (iznos <= 0) {
      throw Exception('Iznos mora biti pozitivan broj');
    }

    // Simuliraj tabelu lookup
    final tabela = putnikId.startsWith('mesecni-') ? 'mesecni_putnici' : 'putovanja_istorija';
    print('- Tabela: $tabela');

    // Simuliraj status
    final status = 'placeno'; // KONZISTENTNO
    print('- Status: $status');

    print('✅ Obično plaćanje - validacija OK');
  } catch (e) {
    print('❌ Obično plaćanje FAILED: $e');
    rethrow;
  }
}

// Helper funkcije za format testiranje
void testFormatValidation() {
  print('\n🔤 TESTIRANJE FORMAT VALIDACIJE...');

  // Test mesec parser
  final testMeseci = [
    'Novembar 2024',
    'Decembar 2024',
    'Januar 2025',
    'Nevažeći format',
    'Mart',
    'April 2024 dodatno',
  ];

  for (final mesec in testMeseci) {
    try {
      final parts = mesec.split(' ');
      if (parts.length != 2) {
        throw Exception('Neispravno format meseca: $mesec');
      }

      final monthName = parts[0];
      final year = int.tryParse(parts[1]);
      if (year == null) {
        throw Exception('Neispravna godina: ${parts[1]}');
      }

      const months = {
        'Januar': 1,
        'Februar': 2,
        'Mart': 3,
        'April': 4,
        'Maj': 5,
        'Jun': 6,
        'Jul': 7,
        'Avgust': 8,
        'Septembar': 9,
        'Oktobar': 10,
        'Novembar': 11,
        'Decembar': 12,
      };

      final monthNumber = months[monthName] ?? 0;
      if (monthNumber == 0) {
        throw Exception('Neispravno ime meseca: $monthName');
      }

      print('✅ $mesec -> Month: $monthNumber, Year: $year');
    } catch (e) {
      print('❌ $mesec -> ERROR: $e');
    }
  }
}

// FINALNI TEST - pronađi TAČNO gde se dešava UUID greška
// Run with: dart run test/debug_uuid_error.dart

void main() {
  print('🕵️ FINALNI DEBUG - pronalaženje UUID greške...\n');

  // Test sve moguće scenarije koji mogu da proузроkују grešku
  testAllPossibleSources();

  print('\n🎯 Debug završen!');
}

void testAllPossibleSources() {
  print('🔍 Testiranje svih mogućih izvora UUID greške:');

  // 1. Test INSERT operacija (novo dodavanje)
  print('\n1️⃣ INSERT operacije:');
  testInsertOperation();

  // 2. Test UPDATE operacija (postojeći podaci)
  print('\n2️⃣ UPDATE operacije:');
  testUpdateOperation();

  // 3. Test različitih UUID kolona
  print('\n3️⃣ UUID kolone u mesecni_putnici:');
  testAllUUIDColumns();
}

void testInsertOperation() {
  // Simulira INSERT kao u MesecniPutnikServiceNovi.dodajMesecniPutnik
  Map<String, dynamic> insertData = {
    'id': '123e4567-e89b-12d3-a456-426614174000',
    'putnik_ime': 'Test Putnik',
    'tip': 'djak',
    'polasci_po_danu': {
      'pon': ['07:00 BC']
    },
    'datum_pocetka_meseca': '2024-01-01',
    'datum_kraja_meseca': '2024-01-31',
    'created_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
    'vozac_id': null, // Ovo je OK
    'ruta_id': null, // Ovo je OK
    'vozilo_id': null, // Ovo je OK
    'adresa_polaska_id': null, // Ovo je OK
    'adresa_dolaska_id': null, // Ovo je OK
  };

  bool hasUUIDError = false;
  insertData.forEach((key, value) {
    if (key.contains('_id') && value is String && value.isEmpty) {
      print('  ❌ GREŠKA: $key = "$value" (prazan string)');
      hasUUIDError = true;
    } else if (key.contains('_id')) {
      print('  ✅ OK: $key = $value');
    }
  });

  if (!hasUUIDError) {
    print('  ✅ INSERT operacija je bezbedna');
  }
}

void testUpdateOperation() {
  // Simulira UPDATE operacije
  List<Map<String, dynamic>> updateScenarios = [
    // Scenario 1: Označavanje pokupljanja
    {
      'pokupljen': true,
      'vozac_id': '', // OVDE MOŽE BITI PROBLEM!
      'updated_at': DateTime.now().toIso8601String()
    },
    // Scenario 2: Plaćanje
    {
      'cena': 1500.0,
      'vozac_id': null, // Ovo je OK
      'vreme_placanja': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String()
    },
    // Scenario 3: Dodavanje nepostojeće kolone
    {
      'naplatio_vozac_id': '', // OVDE JE PROBLEM - nepostojeća kolona!
      'updated_at': DateTime.now().toIso8601String()
    }
  ];

  for (int i = 0; i < updateScenarios.length; i++) {
    print('  Scenario ${i + 1}:');
    final scenario = updateScenarios[i];
    bool hasError = false;

    scenario.forEach((key, value) {
      if (key.contains('_id') && value is String && value.isEmpty) {
        print('    ❌ GREŠKA: $key = "$value" (prazan string za UUID kolonu)');
        hasError = true;
      } else if (key == 'naplatio_vozac_id') {
        print('    ❌ GREŠKA: $key kolona ne postoji u mesecni_putnici tabeli!');
        hasError = true;
      } else if (key.contains('_id')) {
        print('    ✅ OK: $key = $value');
      }
    });

    if (!hasError) {
      print('    ✅ Scenario ${i + 1} je bezbedan');
    }
  }
}

void testAllUUIDColumns() {
  // Sve UUID kolone u mesecni_putnici tabeli
  List<String> uuidColumns = [
    'id',
    'vozac_id',
    'ruta_id',
    'vozilo_id',
    'adresa_polaska_id',
    'adresa_dolaska_id'
  ];

  print('  UUID kolone u mesecni_putnici tabeli:');
  for (String column in uuidColumns) {
    print('    ✅ $column (postoji)');
  }

  // Kolone koje NE postoje ali možda se koriste u kodu
  List<String> nonExistentColumns = [
    'naplatio_vozac_id', // Ovo je iz dnevni_putnici
    'pokupljanje_vozac_id',
    'otkazao_vozac_id'
  ];

  print('  UUID kolone koje NE postoje u mesecni_putnici:');
  for (String column in nonExistentColumns) {
    print('    ❌ $column (ne postoji - može biti uzrok greške!)');
  }
}

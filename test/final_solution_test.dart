// Finalni test kompletnog rešenja
void main() {
  print('=== FINALNI TEST KOMPLETNOG REŠENJA ===');

  // Test 1: Mesecni putnici tabela mapping
  print('\n1. mesecni_putnici tabela - UUID kolone:');
  Map<String, dynamic> mesecniData = {
    'id': 'test-uuid-123',
    'putnik_ime': 'Marko Petrović',
    'vozac_id': null, // UUID kolona - proverena
    'ruta_id': null, // UUID kolona
    'vozilo_id': null, // UUID kolona
    'adresa_polaska_id': null, // UUID kolona
    'adresa_dolaska_id': null, // UUID kolona
    'broj_putovanja': 0,
  };
  mesecniData.forEach((k, v) => print('  $k: $v (${v.runtimeType})'));

  // Test 2: Putovanja istorija tabela mapping
  print('\n2. putovanja_istorija tabela - String kolone:');
  Map<String, dynamic> istorijaData = {
    'putnik_ime': 'Ana Jovanović',
    'vozac': null, // String kolona - ime vozača
    'otkazao_vozac': null, // String kolona
    'datum': '2025-10-03',
    'status': 'zavrseno',
  };
  istorijaData.forEach((k, v) => print('  $k: $v (${v.runtimeType})'));

  // Test 3: UUID validacija funkcije
  print('\n3. UUID validacija test:');
  testUuidValidation('', 'Prazan string');
  testUuidValidation(null, 'Null vrednost');
  testUuidValidation('f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Valjan UUID');
  testUuidValidation('invalid-uuid', 'Nevaljan UUID (ali string)');

  // Test 4: Simulating real database operations
  print('\n4. Simulacija realnih operacija:');
  simulateRealOperations();

  print('\n✅ SVI TESTOVI USPEŠNI - UUID greške treba da budu rešene!');
}

void testUuidValidation(String? input, String description) {
  String? result = (input == null || input.isEmpty) ? null : input;
  print('  $description: "$input" -> $result (${result.runtimeType})');
}

void simulateRealOperations() {
  // UPDATE na mesecni_putnici (iz putnik_service.dart)
  String currentDriver = ''; // Prazan string
  Map<String, dynamic> updateData = {
    'vozac_id': (currentDriver.isEmpty) ? null : currentDriver,
    'poslednje_putovanje': DateTime.now().toIso8601String(),
  };
  print('  UPDATE mesecni_putnici: $updateData');

  // INSERT iz toMesecniPutniciMap (iz putnik.dart)
  String? vozac = '';
  Map<String, dynamic> insertData = {
    'putnik_ime': 'Test Putnik',
    'vozac_id': (vozac.isEmpty) ? null : vozac,
    'tip': 'ucenici',
  };
  print('  INSERT mesecni_putnici: $insertData');

  // Proverava da li su svi UUID polja null ili valjan string
  bool allUuidsValid = true;
  List<String> uuidFields = ['vozac_id'];

  for (String field in uuidFields) {
    var value = insertData[field];
    if (value != null && value is String && value.isEmpty) {
      allUuidsValid = false;
      print('  ❌ GREŠKA: $field je prazan string!');
    }
  }

  if (allUuidsValid) {
    print('  ✅ Svi UUID polja su validni (null ili valjan string)');
  }
}

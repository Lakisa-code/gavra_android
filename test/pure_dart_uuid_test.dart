// Čist Dart test bez Flutter dependencies

void main() {
  print('=== REAL WORLD UUID TEST ===');

  // Test različitih scenarija koje možda aplikacija šalje na bazu

  print('\n1. Test UPDATE scenarija:');
  testUpdateScenario('', 'Prazan string');
  testUpdateScenario(null, 'Null vrednost');
  testUpdateScenario('f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Valjan UUID');

  print('\n2. Test INSERT scenarija:');
  testInsertScenario('', 'Prazan string');
  testInsertScenario(null, 'Null vrednost');
  testInsertScenario('f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Valjan UUID');

  print('\n3. Test toMap() konverzije:');
  testToMapConversion();

  print('\n✅ Svi testovi završeni');
}

void testUpdateScenario(String? vozacId, String description) {
  print('  $description: vozacId = $vozacId');

  // Simulates logic from mesecni_putnik_service_novi.dart
  Map<String, dynamic> updateData = {};

  if (vozacId != null) {
    updateData['vozac_id'] = vozacId.isEmpty ? null : vozacId;
  }

  print('  -> UPDATE data: $updateData');
  if (updateData.containsKey('vozac_id')) {
    print('  -> vozac_id tip: ${updateData['vozac_id'].runtimeType}');
  }
}

void testInsertScenario(String? vozacId, String description) {
  print('  $description: vozacId = $vozacId');

  // Simulates logic from mesecni_putnik_novi.dart toMap()
  Map<String, dynamic> insertData = {
    'id': 'test-uuid',
    'ime': 'Test putnik',
    'vozac_id': (vozacId == null || vozacId.isEmpty) ? null : vozacId,
    'broj_putovanja': 0,
  };

  print(
      '  -> INSERT data vozac_id: ${insertData['vozac_id']} (${insertData['vozac_id'].runtimeType})');
}

void testToMapConversion() {
  // Test različitih vrednosti koje model može da dobije
  List<String?> testValues = ['', null, 'valid-uuid-123', '   ', 'not-uuid'];

  for (String? value in testValues) {
    String? converted = (value == null || value.isEmpty) ? null : value;
    print('  Input: $value -> Output: $converted (${converted.runtimeType})');
  }
}

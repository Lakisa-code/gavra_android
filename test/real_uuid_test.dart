// Real-world test koji simulira problematičnu situaciju
// Run with: dart run test/real_uuid_test.dart

void main() {
  print('🔍 REALNI TEST - simulacija aplikacije...\n');

  // Test svih mogućih vrednosti koje mogu doći iz UI-ja
  testRealWorldScenarios();

  // Test specifično mesecni_putnik_service_novi logike
  testServiceLogic();

  print('\n🎯 Test završen!');
}

void testRealWorldScenarios() {
  print('📱 Test realnih scenarija iz aplikacije:');

  // Moguće vrednosti koje dolaze iz UI-ja
  List<String?> realValues = [
    null, // Nije postavljen
    '', // Prazan string
    '   ', // Samo whitespace
    'undefined', // JS-like
    'null', // String "null"
    '550e8400-e29b-41d4-a716-446655440000', // Validan UUID
  ];

  for (String? value in realValues) {
    final processed = processVozacId(value);
    final status = (processed == null)
        ? '✅ NULL'
        : isValidUUID(processed)
            ? '✅ VALID UUID'
            : '❌ INVALID';

    print('  Input: "$value" → Output: "$processed" $status');
  }
}

void testServiceLogic() {
  print('\n🔧 Test service logike (kao u mesecni_putnik_service_novi):');

  // Simulira UPDATE operaciju
  String vozacFromUI = ''; // Ovo je ono što dolazi iz aplikacije

  Map<String, dynamic> updateData = {
    'pokupljen': true,
    'vozac_id': (vozacFromUI.isEmpty) ? null : vozacFromUI,
    'updated_at': DateTime.now().toIso8601String()
  };

  print('  UPDATE data: $updateData');

  // Proveri da li bi ovo moglo da baci UUID grešku
  final vozacId = updateData['vozac_id'];
  if (vozacId is String && vozacId.isEmpty) {
    print('  ❌ OPASNOST: Ovo će baciti PostgreSQL UUID grešku!');
  } else if (vozacId == null) {
    print('  ✅ BEZBEDNO: null se prihvata u UUID koloni');
  } else if (isValidUUID(vozacId)) {
    print('  ✅ BEZBEDNO: validan UUID');
  } else {
    print('  ❌ OPASNOST: nevalidan UUID format!');
  }
}

// Helper funkcije
String? processVozacId(String? input) {
  if (input == null) return null;
  if (input.trim().isEmpty) return null;
  if (input == 'null' || input == 'undefined') return null;
  return input;
}

bool isValidUUID(String? value) {
  if (value == null) return false;
  final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false);
  return uuidRegex.hasMatch(value);
}

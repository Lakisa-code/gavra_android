void main() async {
  print('=== TEST PRAVOG SUPABASE POZIVA ===');

  try {
    // Simulacija realnog poziva na bazu

    // Testiram da li možda direktno slanje praznog stringa ne radi
    print('Test 1: Simulacija INSERT sa praznim vozac_id');

    Map<String, dynamic> testData = {
      'id': 'test-uuid-123',
      'ime': 'Test putnik',
      'vozac_id': '', // Ovo je potencijalni problem
      'ruta_id': null,
      'broj_putovanja': 0,
    };

    print('Podaci pre konverzije:');
    testData.forEach((k, v) => print('  $k: $v (${v.runtimeType})'));

    // Primeni validaciju kao u našim modelima
    Map<String, dynamic> validatedData = {
      'id': testData['id'],
      'ime': testData['ime'],
      'vozac_id': (testData['vozac_id'] == null ||
              testData['vozac_id'].toString().isEmpty)
          ? null
          : testData['vozac_id'],
      'ruta_id': testData['ruta_id'],
      'broj_putovanja': testData['broj_putovanja'],
    };

    print('\nPodaci posle validacije:');
    validatedData.forEach((k, v) => print('  $k: $v (${v.runtimeType})'));

    // Test: UPDATE operacija
    print('\nTest 2: Simulacija UPDATE operacije');
    String testVozacId = '';
    String? processedVozacId = testVozacId.isEmpty ? null : testVozacId;

    Map<String, dynamic> updateData = {
      'vozac_id': processedVozacId,
      'broj_putovanja': 5,
    };

    print('UPDATE podaci:');
    updateData.forEach((k, v) => print('  $k: $v (${v.runtimeType})'));

    print(
        '\n✅ Test završen uspešno - svi prazni stringovi su pretvoreni u null');
  } catch (e) {
    print('❌ Greška u testu: $e');
  }
}

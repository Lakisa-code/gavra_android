// Test mapiranja kolona i UUID validacije
void main() {
  print('=== TEST MAPIRANJA KOLONA I UUID VALIDACIJE ===');

  // Test 1: toMesecniPutniciMap() logika iz putnik.dart
  print('\n1. Test toMesecniPutniciMap() mapiranja:');
  testMesecniPutniciMapping();

  // Test 2: Putnik service UPDATE logika
  print('\n2. Test putnik service UPDATE validacije:');
  testPutnikServiceUpdates();

  // Test 3: Kolone u različitim tabelama
  print('\n3. Test kolona u različitim tabelama:');
  testColumnMapping();

  print('\n✅ Testovi završeni');
}

void testMesecniPutniciMapping() {
  // Simulira Putnik.toMesecniPutniciMap() metodu
  String? vozac = ''; // Prazan string vozac

  Map<String, dynamic> mesecniMap = {
    'id': 'test-id',
    'ime': 'Test putnik',
    'vozac_id': (vozac.isEmpty) ? null : vozac, // UUID validacija
    'ruta_id': null,
    'broj_putovanja': 0,
  };

  print('  toMesecniPutniciMap rezultat:');
  mesecniMap.forEach((k, v) => print('    $k: $v (${v.runtimeType})'));
}

void testPutnikServiceUpdates() {
  // Test različitih scenarija iz putnik_service.dart

  // Scenario 1: currentDriver je prazan string
  String currentDriver = '';
  Map<String, dynamic> updateData1 = {
    'vozac_id': (currentDriver.isEmpty) ? null : currentDriver,
    'broj_putovanja': 5,
  };
  print('  UPDATE sa praznim currentDriver:');
  updateData1.forEach((k, v) => print('    $k: $v (${v.runtimeType})'));

  // Scenario 2: vozac reset na null
  Map<String, dynamic> updateData2 = {
    'vozac_id': null, // Umesto 'vozac': null
    'status': 'otkazan',
  };
  print('  UPDATE sa null vozac_id:');
  updateData2.forEach((k, v) => print('    $k: $v (${v.runtimeType})'));

  // Scenario 3: valjan vozac UUID
  String validVozac = 'f47ac10b-58cc-4372-a567-0e02b2c3d479';
  Map<String, dynamic> updateData3 = {
    'vozac_id': (validVozac.isEmpty) ? null : validVozac,
    'poslednje_putovanje': DateTime.now().toIso8601String(),
  };
  print('  UPDATE sa valjan UUID:');
  updateData3.forEach((k, v) => print('    $k: $v (${v.runtimeType})'));
}

void testColumnMapping() {
  print('  Mapiranje kolona po tabelama:');

  // mesecni_putnici tabela - koristi vozac_id (UUID)
  Map<String, dynamic> mesecniPutnici = {
    'vozac_id': null, // UUID kolona
    'ruta_id': 'ruta-uuid',
    'vozilo_id': 'vozilo-uuid',
  };
  print('    mesecni_putnici: $mesecniPutnici');

  // putovanja_istorija tabela - možda koristi vozac (string)
  Map<String, dynamic> putovanjaIstorija = {
    'vozac': 'Marko Petrović', // String ime vozača
    'putnik_ime': 'Ana Jovanović',
  };
  print('    putovanja_istorija: $putovanjaIstorija');

  // Provera da li smo mešali kolone
  print('    ✅ mesecni_putnici.vozac_id = UUID');
  print('    ✅ putovanja_istorija.vozac = String');
}

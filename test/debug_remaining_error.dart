// DEBUGGING - Tražim gde se još uvek šalju prazni stringovi
void main() {
  print('🔍 DEBUGGING - TRAŽIM PRAZNE STRINGOVE ZA UUID');
  print('═══════════════════════════════════════════════════════════');

  // Test 1: Proveri da li MesecniPutnikNovi model ima grešku
  print('\n1. Test MesecniPutnikNovi.toMap():');
  testMesecniPutnikNoviToMap();

  // Test 2: Proveri da li još uvek postoje direktni pozivi
  print('\n2. Test direktnih Supabase poziva:');
  testDirectSupabaseCalls();

  // Test 3: Proveri MesecniPutnikServiceNovi
  print('\n3. Test MesecniPutnikServiceNovi operacija:');
  testServiceOperations();

  print('\n🎯 MORA DA POSTOJI JOŠ JEDAN IZVOR PRAZNIH STRINGOVA!');
}

void testMesecniPutnikNoviToMap() {
  // Simulira MesecniPutnikNovi sa praznim poljima
  Map<String, dynamic> testData = {
    'vozac_id': '', // Ovo je problem!
    'ruta_id': '',
    'vozilo_id': '',
    'adresa_polaska_id': '',
    'adresa_dolaska_id': '',
  };

  print('  PRE validacije:');
  testData.forEach((k, v) => print('    $k: "$v" (${v.runtimeType})'));

  // Primeni validaciju
  Map<String, dynamic> validatedData = {};
  testData.forEach((key, value) {
    if (key.endsWith('_id') && value is String) {
      validatedData[key] = value.isEmpty ? null : value;
    } else {
      validatedData[key] = value;
    }
  });

  print('  POSLE validacije:');
  validatedData.forEach((k, v) => print('    $k: $v (${v.runtimeType})'));
}

void testDirectSupabaseCalls() {
  // Test direktnih INSERT/UPDATE poziva
  print('  Mogući problematični pozivi:');

  // INSERT u mesecni_putnici
  Map<String, dynamic> insertData = {
    'id': 'test-uuid',
    'putnik_ime': 'Test',
    'vozac_id': '', // ❌ PROBLEM - prazan string!
  };

  // Primeni fix
  Map<String, dynamic> fixedInsert = Map.from(insertData);
  if (fixedInsert['vozac_id'] == '') {
    fixedInsert['vozac_id'] = null;
  }

  print('    INSERT pre fix: ${insertData['vozac_id']}');
  print('    INSERT posle fix: ${fixedInsert['vozac_id']}');

  // UPDATE u mesecni_putnici
  Map<String, dynamic> updateData = {
    'vozac_id': '', // ❌ PROBLEM - prazan string!
    'broj_putovanja': 5,
  };

  Map<String, dynamic> fixedUpdate = Map.from(updateData);
  if (fixedUpdate['vozac_id'] == '') {
    fixedUpdate['vozac_id'] = null;
  }

  print('    UPDATE pre fix: ${updateData['vozac_id']}');
  print('    UPDATE posle fix: ${fixedUpdate['vozac_id']}');
}

void testServiceOperations() {
  print('  Test različitih service operacija:');

  // azurirajMesecnogPutnika
  String? vozacId = '';
  Map<String, dynamic> updates = {
    'vozac_id': (vozacId.isEmpty) ? null : vozacId,
  };
  print('    azurirajMesecnogPutnika: ${updates['vozac_id']}');

  // dodajMesecnogPutnika
  String? noviVozac = '';
  Map<String, dynamic> newPutnik = {
    'vozac_id': (noviVozac.isEmpty) ? null : noviVozac,
  };
  print('    dodajMesecnogPutnika: ${newPutnik['vozac_id']}');
}

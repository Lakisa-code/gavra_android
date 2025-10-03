// Test novog ID fix-a
void main() {
  print('🔍 TEST NOVOG ID FIX-A');
  print('═══════════════════════════════════════');

  // Test 1: Novi putnik sa praznim ID (INSERT scenario)
  print('\n1. INSERT scenario - prazan ID:');
  Map<String, dynamic> insertData = simulateToMap('', 'Novi Putnik');
  print('   Podaci za INSERT: $insertData');
  print('   Sadrži id polje: ${insertData.containsKey('id')}');

  // Test 2: Postojeći putnik sa ID (UPDATE scenario)
  print('\n2. UPDATE scenario - postojeći ID:');
  Map<String, dynamic> updateData =
      simulateToMap('f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Postojeći Putnik');
  print('   Podaci za UPDATE: $updateData');
  print('   Sadrži id polje: ${updateData.containsKey('id')}');
  print('   ID vrednost: ${updateData['id']}');

  // Test 3: Provera da li PostgreSQL može da primi podatke
  print('\n3. PostgreSQL validacija:');
  validateForPostgreSQL(insertData, 'INSERT');
  validateForPostgreSQL(updateData, 'UPDATE');
}

Map<String, dynamic> simulateToMap(String id, String putnikIme) {
  // Simulira MesecniPutnikNovi.toMap() logiku
  Map<String, dynamic> result = {
    'putnik_ime': putnikIme,
    'tip': 'ucenici',
    'vozac_id': null, // UUID validacija već primenjena
    'broj_putovanja': 0,
  };

  // Dodaj id samo ako nije prazan
  if (id.isNotEmpty) {
    result['id'] = id;
  }

  return result;
}

void validateForPostgreSQL(Map<String, dynamic> data, String operation) {
  bool isValid = true;

  if (operation == 'INSERT') {
    // Za INSERT, id ne sme da postoji ili mora biti null
    if (data.containsKey('id') && data['id'] != null) {
      print('   ❌ $operation: id ne treba da postoji za nova dodavanja');
      isValid = false;
    }
  } else if (operation == 'UPDATE') {
    // Za UPDATE, id mora da postoji i nije null
    if (!data.containsKey('id') || data['id'] == null) {
      print('   ❌ $operation: id mora da postoji za ažuriranje');
      isValid = false;
    }
  }

  // Proveri UUID polja
  data.forEach((key, value) {
    if ((key.endsWith('_id') || key == 'id') &&
        value is String &&
        value.isEmpty) {
      print('   ❌ $operation: $key je prazan string!');
      isValid = false;
    }
  });

  if (isValid) {
    print('   ✅ $operation: Podaci su validni za PostgreSQL');
  }
}

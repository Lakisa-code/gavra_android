// Test MesecniPutnikNovi sa praznim ID
void main() {
  print('🔍 TEST MesecniPutnikNovi sa praznim ID');
  print('═══════════════════════════════════════════');

  // Simulira kreiranje MesecniPutnik sa praznim ID
  Map<String, dynamic> putnik = {
    'id': '', // Prazan string - ovo je problem!
    'putnik_ime': 'Test Putnik',
    'vozac_id': null, // Ovo je OK
  };

  print('PRE UUID validacije:');
  putnik.forEach((k, v) => print('  $k: "$v" (${v.runtimeType})'));

  // Simulira novu UUID validaciju u toMap()
  Map<String, dynamic> validatedPutnik = {
    'id': (putnik['id'] == '') ? null : putnik['id'], // ✅ Fix
    'putnik_ime': putnik['putnik_ime'],
    'vozac_id': putnik['vozac_id'],
  };

  print('\nPOSLE UUID validacije:');
  validatedPutnik.forEach((k, v) => print('  $k: $v (${v.runtimeType})'));

  // Proverava da li će PostgreSQL prihvatiti podatke
  bool hasEmptyUuid = false;
  validatedPutnik.forEach((key, value) {
    if (key.endsWith('_id') || key == 'id') {
      if (value is String && value.isEmpty) {
        print('❌ GREŠKA: $key je prazan string!');
        hasEmptyUuid = true;
      }
    }
  });

  if (!hasEmptyUuid) {
    print('✅ Svi UUID polja su validni - PostgreSQL neće javiti grešku');
  }
}

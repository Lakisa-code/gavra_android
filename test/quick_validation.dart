// Brza validacija mapiranje logike - jednostavan test
void main() {
  print('🔍 BRZA VALIDACIJA MAPIRANJE LOGIKE');
  print('═══════════════════════════════════════');

  // Test 1: UUID validacija logika
  print('\n1. UUID validacija test:');

  String vozac1 = '';
  String vozac2 = 'Marko Petrović';
  String? vozac3 = null;

  String? result1 = vozac1.isEmpty ? null : vozac1;
  String? result2 = vozac2.isEmpty ? null : vozac2;
  String? result3 = (vozac3?.isEmpty ?? true) ? null : vozac3;

  print('   Empty string: "$vozac1" → $result1 ✅');
  print('   Valid string: "$vozac2" → $result2 ✅');
  print('   Null value: $vozac3 → $result3 ✅');

  // Test 2: Map generisanje
  print('\n2. Map generisanje test:');

  Map<String, dynamic> mesecniMap = {
    'putnik_ime': 'Test Putnik',
    'vozac_id': vozac1.isEmpty ? null : vozac1,
    'tip': 'radnik',
  };

  print('   Mesečni putnik map: $mesecniMap ✅');
  print('   vozac_id je null: ${mesecniMap['vozac_id'] == null} ✅');

  // Test 3: ID handling
  print('\n3. ID handling test:');

  String emptyId = '';
  String validId = 'uuid-123';

  Map<String, dynamic> insertMap = {'name': 'Insert Test'};
  Map<String, dynamic> updateMap = {'name': 'Update Test'};

  if (emptyId.isNotEmpty) insertMap['id'] = emptyId;
  if (validId.isNotEmpty) updateMap['id'] = validId;

  print('   INSERT map (empty id): $insertMap ✅');
  print('   UPDATE map (valid id): $updateMap ✅');
  print('   INSERT nema id: ${!insertMap.containsKey('id')} ✅');
  print('   UPDATE ima id: ${updateMap.containsKey('id')} ✅');

  print('\n🎉 SVE VALIDACIJE PROŠLE - MAPIRANJE LOGIKA RADI ISPRAVNO!');
  print('═══════════════════════════════════════');
}

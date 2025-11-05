import 'package:flutter_test/flutter_test.dart';

import '../lib/utils/mesecni_helpers.dart';

void main() {
  group('Debug BC vremena', () {
    test('Test različitih JSON struktura', () {
      // Test 1: JSON sa 5:00 za pon i 6:00 za uto
      final map1 = {
        'polasci_po_danu': '''
        {
          "pon": {"bc": "5:00", "vs": "13:00"},
          "uto": {"bc": "6:00", "vs": "14:00"}
        }
        ''',
      };

      final bcPon1 = MesecniHelpers.getPolazakForDay(map1, 'pon', 'bc');
      final bcUto1 = MesecniHelpers.getPolazakForDay(map1, 'uto', 'bc');

      print('Test 1 - JSON string:');
      print('  BC pon: $bcPon1');
      print('  BC uto: $bcUto1');

      // Test 2: Map direktno
      final map2 = {
        'polasci_po_danu': {
          'pon': {'bc': '5:00', 'vs': '13:00'},
          'uto': {'bc': '6:00', 'vs': '14:00'},
        },
      };

      final bcPon2 = MesecniHelpers.getPolazakForDay(map2, 'pon', 'bc');
      final bcUto2 = MesecniHelpers.getPolazakForDay(map2, 'uto', 'bc');

      print('Test 2 - Map object:');
      print('  BC pon: $bcPon2');
      print('  BC uto: $bcUto2');

      // Test 3: Stare kolone
      final map3 = {
        'polazak_bc_pon': '5:00',
        'polazak_bc_uto': '6:00',
        'polazak_vs_pon': '13:00',
        'polazak_vs_uto': '14:00',
      };

      final bcPon3 = MesecniHelpers.getPolazakForDay(map3, 'pon', 'bc');
      final bcUto3 = MesecniHelpers.getPolazakForDay(map3, 'uto', 'bc');

      print('Test 3 - Stare kolone:');
      print('  BC pon: $bcPon3');
      print('  BC uto: $bcUto3');

      // Test 4: Default fallback
      final map4 = <String, dynamic>{};

      final bcPon4 = MesecniHelpers.getPolazakForDay(map4, 'pon', 'bc');
      final bcUto4 = MesecniHelpers.getPolazakForDay(map4, 'uto', 'bc');

      print('Test 4 - Prazan map:');
      print('  BC pon: $bcPon4 (should be null)');
      print('  BC uto: $bcUto4 (should be null)');

      expect(bcPon1, equals('5:00'));
      expect(bcUto1, equals('6:00'));
      expect(bcPon2, equals('5:00'));
      expect(bcUto2, equals('6:00'));
      expect(bcPon3, equals('5:00'));
      expect(bcUto3, equals('6:00'));
    });
  });
}

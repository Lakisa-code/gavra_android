import 'package:flutter_test/flutter_test.dart';

import '../lib/utils/mesecni_helpers.dart';

void main() {
  group('MesecniHelpers Test', () {
    test('getPolazakForDay should parse correctly', () {
      // Simulacija mesečnog putnika sa polascima
      final mockMap = {
        'id': 'test-123',
        'putnik_ime': 'Test Putnik',
        'polasci_po_danu': {
          'pon': {'bc': '6:00', 'vs': '14:00'},
          'uto': {'bc': '7:00', 'vs': '15:00'},
          'sre': {'bc': '6:00', 'vs': '14:00'},
          'cet': {'bc': '6:00', 'vs': '14:00'},
          'pet': {'bc': '6:00', 'vs': '14:00'},
        },
      };

      // Test za BC pon 6:00
      final bcPon = MesecniHelpers.getPolazakForDay(mockMap, 'pon', 'bc');
      expect(bcPon, '6:00');

      // Test za VS pon 14:00
      final vsPon = MesecniHelpers.getPolazakForDay(mockMap, 'pon', 'vs');
      expect(vsPon, '14:00');

      // Test za BC uto 7:00
      final bcUto = MesecniHelpers.getPolazakForDay(mockMap, 'uto', 'bc');
      expect(bcUto, '7:00');

      print('✅ BC Pon: $bcPon');
      print('✅ VS Pon: $vsPon');
      print('✅ BC Uto: $bcUto');
    });

    test('getPolazakForDay should handle JSON string', () {
      // Test sa JSON string umesto Map
      final mockMapWithJsonString = {
        'id': 'test-456',
        'putnik_ime': 'Test Putnik 2',
        'polasci_po_danu': '{"pon":{"bc":"6:00","vs":"14:00"},"uto":{"bc":"7:00","vs":"15:00"}}',
      };

      final bcPon = MesecniHelpers.getPolazakForDay(mockMapWithJsonString, 'pon', 'bc');
      expect(bcPon, '6:00');

      final vsPon = MesecniHelpers.getPolazakForDay(mockMapWithJsonString, 'pon', 'vs');
      expect(vsPon, '14:00');

      print('✅ JSON BC Pon: $bcPon');
      print('✅ JSON VS Pon: $vsPon');
    });

    test('normalizeTime should work consistently', () {
      // Test normalizacije vremena
      expect(MesecniHelpers.normalizeTime('06:00'), '6:00');
      expect(MesecniHelpers.normalizeTime('6:00'), '6:00');
      expect(MesecniHelpers.normalizeTime('06:00:00'), '6:00');
      expect(MesecniHelpers.normalizeTime('14:30'), '14:30');
      expect(MesecniHelpers.normalizeTime('05:00'), '5:00');
    });
  });
}

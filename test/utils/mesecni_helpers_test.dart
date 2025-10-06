import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/utils/mesecni_helpers.dart';

void main() {
  group('MesecniHelpers', () {
    test('normalizeTime converts HH:MM:SS to H:MM', () {
      expect(MesecniHelpers.normalizeTime('06:00:00'), '06:00');
      expect(MesecniHelpers.normalizeTime('14:05:00'), '14:05');
      expect(MesecniHelpers.normalizeTime('6:5'), '06:05');
      expect(MesecniHelpers.normalizeTime(null), null);
    });

    test('parsePolasciPoDanu parses json string and map', () {
      const json = '{"pon": {"bc": "06:00:00", "vs": "14:00:00"}}';
      final parsed = MesecniHelpers.parsePolasciPoDanu(json);
      expect(parsed.containsKey('pon'), true);
      expect(parsed['pon']!['bc'], '06:00');
      expect(parsed['pon']!['vs'], '14:00');

      const map = {
        'pon': {'bc': '06:00:00'},
      };
      final parsed2 = MesecniHelpers.parsePolasciPoDanu(map);
      expect(parsed2['pon']!['bc'], '06:00');
    });

    test('isActiveFromMap handles obrisan and aktivan', () {
      expect(MesecniHelpers.isActiveFromMap({'obrisan': true}), false);
      expect(MesecniHelpers.isActiveFromMap({'obrisan': 'true'}), false);
      expect(MesecniHelpers.isActiveFromMap({'aktivan': false}), false);
      expect(MesecniHelpers.isActiveFromMap({'aktivan': true}), true);
      expect(MesecniHelpers.isActiveFromMap({}), true);
    });

    test('priceIsPaid detects various paid forms', () {
      expect(MesecniHelpers.priceIsPaid({'placeno': true}), true);
      expect(MesecniHelpers.priceIsPaid({'placeni_mesec': '5'}), true);
      expect(MesecniHelpers.priceIsPaid({'ukupna_cena_meseca': 1200}), true);
      expect(MesecniHelpers.priceIsPaid({'cena': '0'}), false);
      expect(MesecniHelpers.priceIsPaid({}), false);
    });
  });
}

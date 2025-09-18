import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/utils/mesecni_helpers.dart';

void main() {
  test('normalizePolasciForSend handles map input', () {
    final raw = {
      'pon': {'bc': '06:00:00', 'vs': '14:00:00'},
      'uto': {'bc': '6:00', 'vs': null},
    };

    final res = MesecniHelpers.normalizePolasciForSend(raw);

    expect(res['pon']!['bc'], '6:00');
    expect(res['pon']!['vs'], '14:00');
    expect(res['uto']!['bc'], '6:00');
    expect(res['uto']!['vs'], isNull);
  });

  test('buildStatistics extracts basic metrics', () {
    final map = {
      'broj_putovanja': 5,
      'broj_otkazivanja': 2,
      'poslednje_putovanje': '2025-09-10'
    };
    final stat = MesecniHelpers.buildStatistics(map);
    expect(stat['trips_total'], 5);
    expect(stat['trips_cancelled'], 2);
    expect(stat['last_trip_at'], '2025-09-10');
  });
}

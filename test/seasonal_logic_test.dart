import 'package:flutter_test/flutter_test.dart';
import '../lib/utils/seasonal_schedule_manager.dart';

void main() {
  group('Sezonska logika testovi', () {
    test('15. septembar treba da bude zimski period', () {
      final datum = DateTime(2025, 9, 15); // 15. septembar 2025
      expect(SeasonalScheduleManager.isLetniPeriod(datum), false);
      expect(SeasonalScheduleManager.getCurrentSeasonName(datum), 'Zimski');
    });

    test('15. jul treba da bude letnji period', () {
      final datum = DateTime(2025, 7, 15); // 15. jul 2025
      expect(SeasonalScheduleManager.isLetniPeriod(datum), true);
      expect(SeasonalScheduleManager.getCurrentSeasonName(datum), 'Letnji');
    });

    test('15. avgust treba da bude letnji period', () {
      final datum = DateTime(2025, 8, 15); // 15. avgust 2025
      expect(SeasonalScheduleManager.isLetniPeriod(datum), true);
      expect(SeasonalScheduleManager.getCurrentSeasonName(datum), 'Letnji');
    });

    test('1. septembar treba da bude zimski period', () {
      final datum = DateTime(2025, 9, 1); // 1. septembar 2025
      expect(SeasonalScheduleManager.isLetniPeriod(datum), false);
      expect(SeasonalScheduleManager.getCurrentSeasonName(datum), 'Zimski');
    });

    test('30. jun treba da bude zimski period', () {
      final datum = DateTime(2025, 6, 30); // 30. jun 2025
      expect(SeasonalScheduleManager.isLetniPeriod(datum), false);
      expect(SeasonalScheduleManager.getCurrentSeasonName(datum), 'Zimski');
    });

    test('1. jul treba da bude letnji period', () {
      final datum = DateTime(2025, 7, 1); // 1. jul 2025
      expect(SeasonalScheduleManager.isLetniPeriod(datum), true);
      expect(SeasonalScheduleManager.getCurrentSeasonName(datum), 'Letnji');
    });

    test('Opis sezone je ispravan', () {
      final zimski = DateTime(2025, 9, 15);
      final letnji = DateTime(2025, 7, 15);

      expect(SeasonalScheduleManager.getCurrentPeriodDescription(zimski),
          'Zimski red vožnje (1. septembar - 30. jun)');

      expect(SeasonalScheduleManager.getCurrentPeriodDescription(letnji),
          'Letnji red vožnje (1. jul - 31. avgust)');
    });

    test('Datum sledeće sezone je ispravan', () {
      // Za septembar 2025 (zimski), sledeći letnji je 1. jul 2026
      final zimski = DateTime(2025, 9, 15);
      final nextFromZimski =
          SeasonalScheduleManager.getNextSeasonStartDate(zimski);
      expect(nextFromZimski, DateTime(2026, 7, 1));

      // Za jul 2025 (letnji), sledeći zimski je 1. septembar 2025
      final letnji = DateTime(2025, 7, 15);
      final nextFromLetnji =
          SeasonalScheduleManager.getNextSeasonStartDate(letnji);
      expect(nextFromLetnji, DateTime(2025, 9, 1));
    });
  });
}

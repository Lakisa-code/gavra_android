import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/utils/time_validator.dart';

void main() {
  group('TimeValidator Tests', () {
    test('normalizeTimeFormat handles various formats correctly', () {
      expect(TimeValidator.normalizeTimeFormat('6:00'), '06:00');
      expect(TimeValidator.normalizeTimeFormat('06:00:00'), '06:00');
      expect(TimeValidator.normalizeTimeFormat('14:30'), '14:30');
      expect(TimeValidator.normalizeTimeFormat('9'), '09:00');
      expect(TimeValidator.normalizeTimeFormat('invalid'), null);
      expect(TimeValidator.normalizeTimeFormat('25:00'), null); // Invalid hour
    });

    test('validateTime returns correct error messages', () {
      expect(TimeValidator.validateTime('06:00'), null); // Valid
      expect(TimeValidator.validateTime('04:00'),
          'Vreme mora biti između 05:00 i 23:59'); // Too early
      expect(TimeValidator.validateTime('24:00'),
          'Neispravno vreme. Koristite format HH:MM (npr. 08:30)'); // Invalid hour
      expect(TimeValidator.validateTime('08:37'),
          'Minuti moraju biti u intervalima od 5 (00, 05, 10, 15, ...)'); // Invalid minutes
      expect(TimeValidator.validateTime(''), null); // Empty allowed
      expect(TimeValidator.validateTime(null), null); // Null allowed
    });

    test('validateDepartureSequence works correctly', () {
      expect(TimeValidator.validateDepartureSequence('06:00', '07:00'),
          null); // Valid gap
      expect(TimeValidator.validateDepartureSequence('06:00', '06:15'),
          'Razmak između polazaka iz BC i VS mora biti najmanje 30 minuta'); // Too close
      expect(TimeValidator.validateDepartureSequence('14:00', '15:00'),
          null); // Valid gap
      expect(TimeValidator.validateDepartureSequence(null, '06:00'),
          null); // One null
    });

    test('isWithinBusinessHours works correctly', () {
      expect(TimeValidator.isWithinBusinessHours('06:00'), true);
      expect(TimeValidator.isWithinBusinessHours('04:00'), false);
      expect(TimeValidator.isWithinBusinessHours('23:30'), true);
      expect(TimeValidator.isWithinBusinessHours('invalid'), false);
    });

    test('getSuggestedTimes returns appropriate times', () {
      final bcTimes = TimeValidator.getSuggestedTimes('Bela Crkva');
      final vsTimes = TimeValidator.getSuggestedTimes('Vršac');

      expect(bcTimes.contains('06:00'), true);
      expect(vsTimes.contains('07:00'), true);
      expect(bcTimes.length, greaterThan(5));
      expect(vsTimes.length, greaterThan(5));
    });

    test('formatTimeForDisplay works correctly', () {
      expect(TimeValidator.formatTimeForDisplay('06:00'), '06:00');
      expect(TimeValidator.formatTimeForDisplay('06:00', showSeconds: true),
          '06:00:00');
      expect(TimeValidator.formatTimeForDisplay('invalid'),
          'invalid'); // Falls back to original
    });
  });
}

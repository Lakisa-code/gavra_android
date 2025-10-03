/// 🕐 TIME VALIDATION UTILITY
/// Standardizovane funkcije za validaciju i formatiranje vremena
class TimeValidator {
  // Dozvoljeni time format patterns
  static final List<RegExp> _flexibleTimePatterns = [
    RegExp(r'^([0-1]?[0-9]|2[0-3]):([0-5][0-9]):([0-5][0-9])$'), // HH:MM:SS
    RegExp(r'^([0-1]?[0-9]|2[0-3]):([0-5]?[0-9])$'), // HH:MM (flexible minutes)
    RegExp(r'^([0-1]?[0-9]|2[0-3])$'), // HH
  ];

  /// Validates time string and returns error message if invalid
  static String? validateTime(String? timeString) {
    if (timeString == null || timeString.trim().isEmpty) {
      return null; // Allow empty times
    }

    final normalized = normalizeTimeFormat(timeString);
    if (normalized == null) {
      return 'Neispravno vreme. Koristite format HH:MM (npr. 08:30)';
    }

    final parts = normalized.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    // Business logic validation
    if (hour < 5 || hour > 23) {
      return 'Vreme mora biti između 05:00 i 23:59';
    }

    // Check for reasonable minute intervals
    if (minute % 5 != 0) {
      return 'Minuti moraju biti u intervalima od 5 (00, 05, 10, 15, ...)';
    }

    return null; // Valid time
  }

  /// Normalizes various time formats to standard HH:MM format
  static String? normalizeTimeFormat(String? timeString) {
    if (timeString == null || timeString.trim().isEmpty) {
      return null;
    }

    String cleaned = timeString.trim().replaceAll(RegExp(r'[^\d:]'), '');

    // Try each pattern
    for (final pattern in _flexibleTimePatterns) {
      final match = pattern.firstMatch(cleaned);
      if (match != null) {
        final hour = int.parse(match.group(1)!);
        final minute = match.groupCount >= 2 ? int.parse(match.group(2)!) : 0;

        // Validate ranges
        if (hour > 23 || minute > 59) continue;

        return '${hour}:${minute.toString().padLeft(2, '0')}';
      }
    }

    // Try parsing single number as hour
    final hourOnly = int.tryParse(cleaned);
    if (hourOnly != null && hourOnly >= 0 && hourOnly <= 23) {
      return '${hourOnly}:00';
    }

    return null; // Invalid format
  }

  /// Validates that departure times are in logical order
  static String? validateDepartureSequence(String? bcTime, String? vsTime) {
    if (bcTime == null || vsTime == null) return null;

    final bc = normalizeTimeFormat(bcTime);
    final vs = normalizeTimeFormat(vsTime);

    if (bc == null || vs == null) return null;

    final bcMinutes = _timeToMinutes(bc);
    final vsMinutes = _timeToMinutes(vs);

    // Allow reasonable time gaps between BC and VS departures
    final timeDiff = (vsMinutes - bcMinutes).abs();
    if (timeDiff < 30) {
      return 'Razmak između polazaka iz BC i VS mora biti najmanje 30 minuta';
    }

    return null;
  }

  /// Converts HH:MM to minutes since midnight
  static int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  /// Validates that time is within business hours
  static bool isWithinBusinessHours(String timeString) {
    final normalized = normalizeTimeFormat(timeString);
    if (normalized == null) return false;

    final minutes = _timeToMinutes(normalized);
    return minutes >= 300 && minutes <= 1440; // 05:00 to 24:00
  }

  /// Gets suggested times based on common departure patterns
  static List<String> getSuggestedTimes(String city) {
    if (city.toLowerCase().contains('bela') ||
        city.toLowerCase().contains('crkva')) {
      return [
        '05:00',
        '06:00',
        '07:00',
        '08:00',
        '09:00',
        '11:00',
        '12:00',
        '13:00',
        '14:00',
        '15:30',
        '18:00'
      ];
    } else if (city.toLowerCase().contains('vr')) {
      return [
        '06:00',
        '07:00',
        '08:00',
        '10:00',
        '11:00',
        '12:00',
        '13:00',
        '14:00',
        '15:30',
        '17:00',
        '19:00'
      ];
    }
    return ['06:00', '07:00', '08:00', '12:00', '14:00', '18:00'];
  }

  /// Formats time for display with optional seconds
  static String formatTimeForDisplay(String timeString,
      {bool showSeconds = false}) {
    final normalized = normalizeTimeFormat(timeString);
    if (normalized == null) return timeString;

    if (showSeconds) {
      return '$normalized:00';
    }
    return normalized;
  }
}

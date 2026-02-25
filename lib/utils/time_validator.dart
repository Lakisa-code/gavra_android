/// TIME VALIDATION UTILITY
/// Standardizovane funkcije za validaciju i formatiranje vremena
class TimeValidator {
  // Dozvoljeni time format patterns
  static final List<RegExp> _flexibleTimePatterns = [
    RegExp(r'^([0-1]?[0-9]|2[0-3]):([0-5][0-9]):([0-5][0-9])$'), // HH:MM:SS
    RegExp(r'^([0-1]?[0-9]|2[0-3]):([0-5]?[0-9])$'), // HH:MM (flexible minutes)
    RegExp(r'^([0-1]?[0-9]|2[0-3])$'), // HH
  ];

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

        return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      }
    }

    // Try parsing single number as hour
    final hourOnly = int.tryParse(cleaned);
    if (hourOnly != null && hourOnly >= 0 && hourOnly <= 23) {
      return '${hourOnly.toString().padLeft(2, '0')}:00';
    }

    return null; // Invalid format
  }
}

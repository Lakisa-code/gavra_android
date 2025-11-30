bool isZimski(DateTime date) {
  // Zimski period: from September 1 (inclusive) to July 1 (exclusive)
  // Interpreting user's rule: "od 1 septembra do 1 jula je zimski"
  // That means: Sep 1 .. Jun 30 are considered zimski.
  final year = date.year;
  final sep1 = DateTime(year, 9);
  final jul1 = DateTime(year, 7);

  if (date.isAtSameMomentAs(sep1) || (date.isAfter(sep1))) {
    // From Sep 1 until Dec 31 => zimski
    return true;
  }

  // From Jan 1 until Jun 30 => still zimski
  final jan1 = DateTime(year);
  if (date.isAfter(jan1.subtract(const Duration(days: 1))) && date.isBefore(jul1)) {
    return true;
  }

  return false;
}

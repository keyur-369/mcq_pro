/// Utility helper for dynamic academic year calculation and management
class AcademicYearUtils {
  /// Returns the current academic year based on the calendar date.
  /// In typical educational calendars, sessions run starting in mid-year.
  /// If month >= 5 (May), start year is current year; otherwise, previous year.
  static String getCurrentAcademicYear() {
    final now = DateTime.now();
    final startYear = now.month >= 5 ? now.year : now.year - 1;
    return '$startYear-${startYear + 1}';
  }

  /// Generates a dynamic list of academic years.
  /// Generates a multi-year window (e.g. 2024-2025 up to 2035-2036 and beyond).
  /// Automatically includes [extraYear] if supplied.
  static List<String> getDynamicAcademicYears({
    int pastYears = 2,
    int futureYears = 8,
    String? extraYear,
  }) {
    final now = DateTime.now();
    final currentStart = now.month >= 5 ? now.year : now.year - 1;
    final baseStart = currentStart < 2026 ? 2026 : currentStart;
    final minYear = (baseStart - pastYears) < 2024 ? 2024 : (baseStart - pastYears);
    final maxYear = (baseStart + futureYears) < 2035 ? 2035 : (baseStart + futureYears);

    final set = <String>{};
    for (int y = minYear; y <= maxYear; y++) {
      set.add('$y-${y + 1}');
    }

    if (extraYear != null && extraYear.trim().isNotEmpty) {
      set.add(extraYear.trim());
    }

    final list = set.toList()..sort();
    return list;
  }

  /// Formats a starting year into an academic year string (e.g. 2028 -> '2028-2029').
  static String formatFromStartYear(int startYear) {
    return '$startYear-${startYear + 1}';
  }
}

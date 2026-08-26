/// Small formatting helpers shared by the portal screens — ported from the
/// website's inline helpers (`mbToGb`, `formatDate`) so numbers/dates read
/// identically in both apps without pulling in the `intl` package.
class Formatters {
  Formatters._();

  static const _arabicMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  static const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  /// Converts megabytes to a "12.34" GB string with two decimals, or null
  /// for missing/invalid input (mirrors the website's `mbToGb`).
  static String? mbToGb(num? mb) {
    if (mb == null || mb < 0) return null;
    return (mb / 1024).toStringAsFixed(2);
  }

  /// Same as [mbToGb] but formatted with a trailing " GB" unit, defaulting
  /// to "0.00 GB" for missing values (mirrors the website's `formatGb`).
  static String formatGb(num? mb) {
    final gb = mbToGb(mb);
    return gb != null ? '$gb GB' : '0.00 GB';
  }

  /// Renders a date (ISO-ish string or [DateTime]) the same way the
  /// website does with `toLocaleDateString('ar-LY', { long month })`,
  /// e.g. "24 سبتمبر 2020".
  static String arabicDate(Object? date) {
    if (date == null) return '—';
    final parsed = date is DateTime ? date : DateTime.tryParse(date.toString());
    if (parsed == null) return '—';
    return '${parsed.day} ${_arabicMonths[parsed.month - 1]} ${parsed.year}';
  }

  /// Converts Western digits in [input] to Eastern Arabic-Indic digits
  /// (٠١٢٣...), used for a couple of website-matching numeric displays.
  static String easternArabicDigits(Object input) {
    return input.toString().split('').map((c) {
      final d = int.tryParse(c);
      return d == null ? c : _arabicDigits[d];
    }).join();
  }
}

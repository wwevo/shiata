/// Shared formatting utilities used throughout the app.
///
/// All number and time formatting should use these functions to ensure
/// consistency across the entire codebase.
library;

import 'dart:math';

/// Generates a random ID with a given prefix and a 6-character random suffix.
///
/// Example: _generateRandomId('kind_') -> 'kind_a7x9f2'
String generateRandomId(String prefix) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rnd = Random();
  final suffix = String.fromCharCodes(
    Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
  );
  return '$prefix$suffix';
}

/// Formats a double value to a string, removing trailing zeros.
///
/// Examples:
/// - 1.0 → "1"
/// - 1.5 → "1.5"
/// - 1.123456 → "1.123456"
/// - 0.0 → "0"
String fmtDouble(num value) {
  final s = value.toDouble().toStringAsFixed(6);
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// Parses a string to a double, returning null if parsing fails or string is empty.
///
/// Examples:
/// - "1.5" → 1.5
/// - "0" → 0.0
/// - "" → null
/// - "abc" → null
/// - null → null
double? parseDouble(String? text) {
  final trimmed = (text ?? '').trim().replaceAll(',', '.');
  if (trimmed.isEmpty) return null;
  return double.tryParse(trimmed);
}

/// Parses a string to an integer, supporting comma/dot separators if they result in a whole number.
///
/// Examples:
/// - "100" → 100
/// - "100,0" → 100
/// - "100.5" → null (not an integer)
/// - "" → null
int? parseInt(String? text) {
  final d = parseDouble(text);
  if (d == null) return null;
  if (d % 1 != 0) return null;
  return d.toInt();
}

/// Formats a DateTime to HH:mm format.
///
/// Examples:
/// - DateTime(2024, 1, 1, 9, 5) → "09:05"
/// - DateTime(2024, 1, 1, 14, 30) → "14:30"
String fmtTime(DateTime dateTime) {
  final h = dateTime.hour.toString().padLeft(2, '0');
  final m = dateTime.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Formats a DateTime to "Month Day" format (e.g., "Aug 10").
String fmtMonthDay(DateTime dt) {
  return '${_monthNames[dt.month - 1]} ${dt.day}';
}

/// Formats a date range from start to end (e.g., "Aug 10 - Aug 16").
String fmtDateRange(DateTime start, DateTime end) {
  return '${fmtMonthDay(start)} - ${fmtMonthDay(end)}';
}

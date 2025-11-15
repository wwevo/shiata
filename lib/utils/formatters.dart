/// Shared formatting utilities used throughout the app.
///
/// All number and time formatting should use these functions to ensure
/// consistency across the entire codebase.

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
  final trimmed = (text ?? '').trim();
  if (trimmed.isEmpty) return null;
  return double.tryParse(trimmed);
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

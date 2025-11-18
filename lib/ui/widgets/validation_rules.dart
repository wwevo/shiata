/// Central validation rules for all editor dialogs.
///
/// Provides consistent validation logic across UI and repository layers.
/// Use these validators in TextFormField widgets for instant user feedback.
library;

class ValidationRules {
  /// Validates that a text field is not empty.
  ///
  /// Returns null if valid, error message if invalid.
  static String? required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates that a numeric amount is >= 0.
  ///
  /// Used for nutrient amounts where negative values don't make sense.
  /// Returns null if valid, error message if invalid.
  static String? nonNegativeAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required';
    }
    final num = double.tryParse(value.trim());
    if (num == null) {
      return 'Must be a valid number';
    }
    if (num < 0) {
      return 'Amount must be >= 0';
    }
    return null;
  }

  /// Validates that grams value is > 0.
  ///
  /// Used for product grams where zero or negative values are invalid.
  /// Returns null if valid, error message if invalid.
  static String? positiveGrams(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Grams is required';
    }
    final num = int.tryParse(value.trim());
    if (num == null) {
      return 'Must be a valid number';
    }
    if (num <= 0) {
      return 'Grams must be > 0';
    }
    return null;
  }

  /// Validates that a positive integer is entered.
  ///
  /// Used for any field requiring integers > 0.
  /// Returns null if valid, error message if invalid.
  static String? positiveInteger(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Value is required';
    }
    final num = int.tryParse(value.trim());
    if (num == null) {
      return 'Must be a valid integer';
    }
    if (num <= 0) {
      return 'Must be > 0';
    }
    return null;
  }

  /// Validates min <= max for numeric ranges.
  ///
  /// Used for kind templates with min/max thresholds.
  /// Returns null if valid, error message if invalid.
  static String? validateRange(int min, int max) {
    if (min > max) {
      return 'Min ($min) cannot be greater than max ($max)';
    }
    return null;
  }
}

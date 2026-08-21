import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/formatters.dart';

/// Mixin providing standard form state, validation, saving logic, and
/// fullscreen scaffold structure for editor dialogs.
mixin EditorDialogShell<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final formKey = GlobalKey<FormState>();
  bool loading = false;
  bool saving = false;
  String? saveError;

  /// Wraps a save operation with loading/saving state and error handling.
  Future<void> safeSave({
    required Future<void> Function() onSave,
    bool closeAfter = false,
  }) async {
    if (saving) return;

    setState(() {
      saveError = null;
      saving = true;
    });

    if (!(formKey.currentState?.validate() ?? true)) {
      setState(() => saving = false);
      return;
    }

    final navigator = Navigator.of(context);

    try {
      await onSave();
      if (!mounted) return;
      if (closeAfter) {
        navigator.pop();
      }
    } on ArgumentError catch (e) {
      if (mounted) setState(() => saveError = e.message);
    } on StateError catch (e) {
      if (mounted) setState(() => saveError = e.message);
    } catch (e) {
      debugPrint('Unexpected error in save: $e');
      if (mounted) setState(() => saveError = 'An unexpected error occurred');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  /// Builds the consistent shell for all editor dialogs.
  Widget buildShell({
    required BuildContext context,
    required String title,
    required Widget content,
    required Future<void> Function({required bool closeAfter}) onSave,
  }) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: editorDialogActions(
            context: context,
            onSave: onSave,
            isSaving: saving,
          ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (saveError != null) InlineError(message: saveError!),
                      content,
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// Reusable action buttons for editor dialogs.
/// Provides consistent "Cancel", "Save", and "Save & Close" buttons.
List<Widget> editorDialogActions({
  required BuildContext context,
  required Future<void> Function({required bool closeAfter}) onSave,
  bool isSaving = false,
}) {
  return [
    TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Cancel'),
    ),
    OutlinedButton(
      onPressed: isSaving ? null : () => onSave(closeAfter: false),
      child: const Text('Save'),
    ),
    FilledButton(
      onPressed: isSaving ? null : () => onSave(closeAfter: true),
      child: const Text('Save & Close'),
    ),
  ];
}

/// Displays critical errors inline within dialogs.
///
/// This widget replaces error snackbars that disappear. Errors stay visible
/// until resolved, allowing users to intervene and correct issues before
/// retrying.
class InlineError extends StatelessWidget {
  const InlineError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Central validation rules for all editor dialogs.
///
/// Provides consistent validation logic across UI and repository layers.
/// Use these validators in TextFormField widgets for instant user feedback.
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
  /// Used for kind amounts where negative values don't make sense.
  /// Returns null if valid, error message if invalid.
  static String? nonNegativeAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required';
    }
    final num = parseDouble(value);
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
    final num = parseInt(value);
    if (num == null) {
      return 'Must be a valid integer';
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
    final num = parseInt(value);
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

/// Helper function to pick a date and time sequentially.
Future<DateTime?> pickDateTime(BuildContext context, DateTime initial) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime.now().subtract(const Duration(days: 3650)),
    lastDate: DateTime.now().add(const Duration(days: 3650)),
  );
  if (date == null) return null;
  if (!context.mounted) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
      child: child ?? const SizedBox.shrink(),
    ),
  );
  if (time == null) return null;

  return DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );
}

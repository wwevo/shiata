import 'package:flutter/material.dart';

/// Reusable action buttons for editor dialogs.
/// Provides consistent "Cancel", "Save", and "Save & Close" buttons.
///
/// Usage:
/// ```dart
/// actions: editorDialogActions(
///   context: context,
///   onSave: ({required closeAfter}) => _save(context, closeAfter: closeAfter),
///   isSaving: _saving,
/// )
/// ```
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

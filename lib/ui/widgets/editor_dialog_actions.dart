import 'package:flutter/material.dart';

/// Reusable action buttons for editor dialogs.
/// Provides consistent "Cancel", "Save", and "Save & Close" buttons.
class EditorDialogActions extends StatelessWidget {
  const EditorDialogActions({
    super.key,
    required this.onSave,
    this.isSaving = false,
  });

  /// Called when Save or Save & Close is pressed.
  /// The [closeAfter] parameter indicates whether to close the dialog after saving.
  final Future<void> Function({required bool closeAfter}) onSave;

  /// Whether a save operation is in progress (disables buttons).
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
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
}

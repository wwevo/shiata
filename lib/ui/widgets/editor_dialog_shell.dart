import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'editor_dialog_actions.dart';
import 'inline_error.dart';

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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/kinds_repository.dart';
import '../widgets/editor_dialog_actions.dart';
import '../widgets/inline_error.dart';
import '../widgets/validation_rules.dart';

class KindTemplateEditorDialog extends ConsumerStatefulWidget {
  const KindTemplateEditorDialog({super.key, this.existing});

  final KindDef? existing;

  @override
  ConsumerState<KindTemplateEditorDialog> createState() =>
      _KindTemplateEditorDialogState();
}

class _KindTemplateEditorDialogState
    extends ConsumerState<KindTemplateEditorDialog> {
  // State variables
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _id;
  late final TextEditingController _name;
  late String _unit;
  late final TextEditingController _min;
  late final TextEditingController _max;
  late bool _defaultShow;
  late final TextEditingController _icon;
  late final TextEditingController _color;
  String? _saveError;

  static const _units = <String>['g', 'mg', 'ug', 'mL'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _id = TextEditingController(text: e?.id ?? '');
    _name = TextEditingController(text: e?.name ?? '');
    _unit = e?.unit ?? 'g';
    _min = TextEditingController(text: (e?.min ?? 0).toString());
    _max = TextEditingController(text: (e?.max ?? 100).toString());
    _defaultShow = e?.defaultShowInCalendar ?? false;
    _icon = TextEditingController(text: e?.icon ?? '');
    _color = TextEditingController(text: (e?.color ?? 0xFF607D8B).toString());
  }

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _min.dispose();
    _max.dispose();
    _icon.dispose();
    _color.dispose();
    super.dispose();
  }

  Future<void> _save(BuildContext context, {bool closeAfter = false}) async {
    // Clear previous errors
    setState(() => _saveError = null);

    // UI validation first
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(kindsRepositoryProvider);
    if (repo == null) return;

    final min = int.tryParse(_min.text.trim()) ?? 0;
    final max = int.tryParse(_max.text.trim()) ?? 0;
    final color = int.tryParse(_color.text.trim());

    final def = KindDef(
      id: _id.text.trim(),
      name: _name.text.trim(),
      unit: _unit,
      color: color,
      icon: _icon.text.trim().isEmpty ? null : _icon.text.trim(),
      min: min,
      max: max,
      defaultShowInCalendar: _defaultShow,
    );

    // Capture context-dependent objects before async gap
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final isEdit = widget.existing != null;

    try {
      // Repository validation happens here
      await repo.upsertKind(def);

      // Success feedback
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(isEdit ? 'Updated kind' : 'Created kind')),
      );
      if (closeAfter && mounted) navigator.pop();
    } on ArgumentError catch (e) {
      // User input error - show inline
      if (mounted) setState(() => _saveError = e.message);
    } on StateError catch (e) {
      // Constraint violation - show inline
      if (mounted) setState(() => _saveError = e.message);
    } catch (e) {
      // Unexpected error - debug only
      debugPrint('Unexpected error in save: $e');
      if (mounted) {
        setState(() => _saveError = 'An unexpected error occurred');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit kind' : 'Add kind'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show repository errors inline
              if (_saveError != null) InlineError(message: _saveError!),
              TextFormField(
                controller: _id,
                enabled: !isEdit,
                decoration: const InputDecoration(
                  labelText: 'Id (stable, e.g., protein)',
                ),
                validator: (v) => ValidationRules.required(v, 'Id'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name (display)'),
                validator: (v) => ValidationRules.required(v, 'Name'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _unit,
                items: _units
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) => setState(() => _unit = v ?? _unit),
                decoration: const InputDecoration(labelText: 'Unit'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _min,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Min (inclusive, int)',
                ),
                validator: _intValidator,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _max,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Max (inclusive, int)',
                ),
                validator: _intValidator,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Default: show in calendar'),
                value: _defaultShow,
                onChanged: (v) => setState(() => _defaultShow = v),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _icon,
                decoration: const InputDecoration(
                  labelText: 'Icon name (Material glyph, optional)',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _color,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Color ARGB int (e.g., 4283657726)',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null; // optional
                  return int.tryParse(v) == null ? 'Must be an integer' : null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: editorDialogActions(
        context: context,
        onSave: ({required closeAfter}) =>
            _save(context, closeAfter: closeAfter),
      ),
    );
  }

  String? _intValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return int.tryParse(v.trim()) == null ? 'Must be an integer' : null;
  }
}

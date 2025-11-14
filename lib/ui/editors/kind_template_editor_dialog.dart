
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/kinds_repository.dart';

class KindTemplateEditorDialog extends ConsumerStatefulWidget {
  const KindTemplateEditorDialog({super.key, this.existing});
  final KindDef? existing;

  @override
  ConsumerState<KindTemplateEditorDialog> createState() => _KindTemplateEditorDialogState();
}

class _KindTemplateEditorDialogState extends ConsumerState<KindTemplateEditorDialog> {
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
              TextFormField(
                controller: _id,
                enabled: !isEdit,
                decoration: const InputDecoration(labelText: 'Id (stable, e.g., protein)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name (display)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _unit,
                items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (v) => setState(() => _unit = v ?? _unit),
                decoration: const InputDecoration(labelText: 'Unit'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _min,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Min (inclusive, int)'),
                validator: _intValidator,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _max,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Max (inclusive, int)'),
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
                decoration: const InputDecoration(labelText: 'Icon name (Material glyph, optional)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _color,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Color ARGB int (e.g., 4283657726)'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null; // optional
                  return int.tryParse(v) == null ? 'Must be an integer' : null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            final repo = ref.read(kindsRepositoryProvider);
            if (repo == null) return;
            final min = int.tryParse(_min.text.trim()) ?? 0;
            final max = int.tryParse(_max.text.trim()) ?? 0;
            if (min > max) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Min cannot be greater than max')),
              );
              return;
            }
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
            await repo.upsertKind(def);
            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(isEdit ? 'Updated kind' : 'Created kind')),
              );
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  String? _intValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return int.tryParse(v.trim()) == null ? 'Must be an integer' : null;
  }
}

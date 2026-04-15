import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/kinds_repository.dart';
import '../../utils/formatters.dart';
import '../widgets/editor_dialog_shell.dart';
import '../widgets/validation_rules.dart';

class KindTemplateEditorDialog extends ConsumerStatefulWidget {
  const KindTemplateEditorDialog({super.key, this.existing});

  final KindDef? existing;

  @override
  ConsumerState<KindTemplateEditorDialog> createState() =>
      _KindTemplateEditorDialogState();
}

class _KindTemplateEditorDialogState
    extends ConsumerState<KindTemplateEditorDialog> with EditorDialogShell {
  // State variables
  late final TextEditingController _id;
  late final TextEditingController _name;
  late String _unit;
  late final TextEditingController _min;
  late final TextEditingController _max;
  late bool _defaultShow;
  late final TextEditingController _icon;
  late final TextEditingController _color;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _id = TextEditingController(text: e?.id ?? generateRandomId('kind_'));
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

  Future<void> _onSave({required bool closeAfter}) async {
    await safeSave(
      closeAfter: closeAfter,
      onSave: () async {
        final repo = ref.read(kindsRepositoryProvider);
        if (repo == null) return;

        final min = parseInt(_min.text) ?? 0;
        final max = parseInt(_max.text) ?? 0;
        final color = parseInt(_color.text);

        final def = KindDef(
          id: _id.text.trim(),
          name: _name.text.trim(),
          unit: _unit,
          color: color,
          icon: _icon.text.trim().isEmpty ? null : _icon.text.trim(),
          min: min,
          max: max,
          defaultShowInCalendar: _defaultShow,
          isProtected: widget.existing?.isProtected ?? false,
        );

        await repo.upsertKind(def);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final unitsAsync = ref.watch(unitsListProvider);
    final units = unitsAsync.value ?? [];

    return buildShell(
      context: context,
      title: isEdit ? 'Edit kind' : 'Add kind',
      onSave: ({required closeAfter}) => _onSave(closeAfter: closeAfter),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _id,
            enabled: !(widget.existing?.isProtected ?? false),
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
            initialValue: units.any((u) => u.id == _unit) ? _unit : null,
            items: units
                .map((u) => DropdownMenuItem(value: u.id, child: Text(u.label)))
                .toList(),
            onChanged: (v) => setState(() => _unit = v ?? _unit),
            decoration: const InputDecoration(labelText: 'Unit'),
            validator: (v) => ValidationRules.required(v, 'Unit'),
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
          ExpansionTile(
            title: const Text('Presentation'),
            children: [
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
                  return parseInt(v) == null ? 'Must be an integer' : null;
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _intValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return parseInt(v) == null ? 'Must be an integer' : null;
  }
}

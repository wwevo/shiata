import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/entries_repository.dart';
import '../../domain/widgets/registry.dart';
import '../../domain/widgets/widget_kind.dart';
import '../../utils/formatters.dart';
import '../widgets/editor_dialog_actions.dart';

class InstanceComponentsEditorDialog extends ConsumerStatefulWidget {
  const InstanceComponentsEditorDialog({super.key, required this.parentEntryId});
  final String parentEntryId;

  @override
  ConsumerState<InstanceComponentsEditorDialog> createState() => _InstanceComponentsEditorDialogState();
}

class _InstanceComponentsEditorDialogState extends ConsumerState<InstanceComponentsEditorDialog> {
  // State variables
  bool _loading = true;
  bool _saving = false;
  List<EntryRecord> _children = const [];
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(entriesRepositoryProvider);
    if (repo == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final list = await repo.listChildrenOfParent(widget.parentEntryId);
    if (mounted) {
      setState(() {
        _children = list;
        _loading = false;
      });
    }
    // Initialize controllers
    for (final c in list) {
      try {
        final map = jsonDecode(c.payloadJson) as Map<String, dynamic>;
        final amount = (map['amount'] as num?)?.toDouble() ?? 0.0;
        _controllers[c.id] = TextEditingController(text: fmtDouble(amount));
      } catch (_) {
        _controllers[c.id] = TextEditingController(text: '0');
      }
    }
  }

  @override
  void dispose() {
    for (final t in _controllers.values) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _save(BuildContext context, {bool closeAfter = false}) async {
    setState(() => _saving = true);
    final repo = ref.read(entriesRepositoryProvider);
    final registry = ref.read(widgetRegistryProvider);
    if (repo == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    // Mark parent as static on first override
    await repo.update(widget.parentEntryId, {'is_static': 1});
    // Update each child payload amount
    for (final c in _children) {
      final ctrl = _controllers[c.id]!;
      final val = double.tryParse(ctrl.text.trim()) ?? 0.0;
      try {
        final map = jsonDecode(c.payloadJson) as Map<String, dynamic>;
        // preserve unit if present, or derive from kind metadata
        final unit = (map['unit'] as String?) ?? (registry.byId(c.widgetKind)?.unit);
        final newPayload = <String, Object?>{'amount': val};
        if (unit != null) newPayload['unit'] = unit;
        await repo.update(c.id, {
          'payload_json': jsonEncode(newPayload),
        });
      } catch (_) {
        await repo.update(c.id, {
          'payload_json': jsonEncode({'amount': val, 'unit': registry.byId(c.widgetKind)?.unit}),
        });
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated components (instance is now Static)')));
    if (mounted) setState(() => _saving = false);
    if (closeAfter && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _addComponent() async {
    final registry = ref.read(widgetRegistryProvider);
    final repo = ref.read(entriesRepositoryProvider);
    if (repo == null) return;

    // Get all available kinds
    final allKinds = registry.kinds.toList();
    // Filter out kinds that already exist in children
    final existingKindIds = _children.map((c) => c.widgetKind).toSet();
    final availableKinds = allKinds.where((k) => !existingKindIds.contains(k.id)).toList();

    if (availableKinds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All nutrients already added')),
      );
      return;
    }

    final picked = await showDialog<WidgetKind?>(
      context: context,
      builder: (ctx) => _AddNutrientDialog(kinds: availableKinds),
    );
    if (picked == null) return;

    // Get parent entry to extract targetAt
    final parent = await repo.getById(widget.parentEntryId);
    if (parent == null) return;

    // Create new child entry with the selected kind
    final newEntryId = await repo.create(
      widgetKind: picked.id,
      targetAtLocal: DateTime.fromMillisecondsSinceEpoch(parent.targetAt, isUtc: true).toLocal(),
      payload: {'amount': 0.0, 'unit': picked.unit},
      showInCalendar: false,
      schemaVersion: 1,
      sourceEntryId: widget.parentEntryId,
    );

    // Reload to include the new entry
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(widgetRegistryProvider);

    return AlertDialog(
      title: const Text('Edit components (Static)'),
      content: _loading
          ? const SizedBox(
        width: 500,
        height: 400,
        child: Center(child: CircularProgressIndicator()),
      )
          : SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            Expanded(
              child: _children.isEmpty
                  ? const Center(child: Text('No components yet'))
                  : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _children.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final e = _children[i];
                  final kind = registry.byId(e.widgetKind);
                  final icon = kind?.icon ?? Icons.circle;
                  final color = kind?.accentColor ?? Theme.of(context).colorScheme.primary;
                  final unit = kind?.unit ?? '';
                  final ctrl = _controllers[e.id]!;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      child: Icon(icon, size: 18),
                    ),
                    title: Text(kind?.displayName ?? e.widgetKind),
                    subtitle: Text(unit.isEmpty ? '' : 'Unit: $unit'),
                    trailing: SizedBox(
                      width: 100,
                      child: TextField(
                        controller: ctrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          hintText: '0',
                          isDense: true,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _addComponent,
                icon: const Icon(Icons.add),
                label: const Text('Add nutrient'),
              ),
            ),
          ],
        ),
      ),
      actions: editorDialogActions(
        context: context,
        onSave: ({required closeAfter}) => _save(context, closeAfter: closeAfter),
        isSaving: _saving,
      ),
    );
  }
}

class _AddNutrientDialog extends StatefulWidget {
  const _AddNutrientDialog({required this.kinds});
  final List<WidgetKind> kinds;

  @override
  State<_AddNutrientDialog> createState() => _AddNutrientDialogState();
}

class _AddNutrientDialogState extends State<_AddNutrientDialog> {
  WidgetKind? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add nutrient'),
      content: DropdownButtonFormField<WidgetKind>(
        value: _selected,
        items: [
          for (final k in widget.kinds)
            DropdownMenuItem(value: k, child: Text(k.displayName)),
        ],
        onChanged: (v) => setState(() => _selected = v),
        decoration: const InputDecoration(labelText: 'Select nutrient'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final k = _selected;
            if (k == null) return;
            Navigator.of(context).pop(k);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

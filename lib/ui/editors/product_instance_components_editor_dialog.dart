import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/entries_repository.dart';
import '../../domain/widgets/registry.dart';
import '../../domain/widgets/widget_kind.dart';
import '../../utils/formatters.dart';
import '../widgets/add_kind_dialog.dart';
import '../widgets/editor_dialog_shell.dart';
import '../widgets/validation_rules.dart';

class InstanceComponentsEditorDialog extends ConsumerStatefulWidget {
  const InstanceComponentsEditorDialog({
    super.key,
    required this.parentEntryId,
  });

  final String parentEntryId;

  @override
  ConsumerState<InstanceComponentsEditorDialog> createState() =>
      _InstanceComponentsEditorDialogState();
}

class _InstanceComponentsEditorDialogState
    extends ConsumerState<InstanceComponentsEditorDialog>
    with EditorDialogShell {
  // State variables
  List<EntryRecord> _children = const [];
  final Map<String, TextEditingController> _controllers = {};
  String? _parentName;

  // Pending changes (transient until Save)
  final List<WidgetKind> _pendingAdds = [];
  final Set<String> _pendingDeletes = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final repo = ref.read(entriesRepositoryProvider);
    if (repo == null) {
      if (mounted) setState(() => loading = false);
      return;
    }

    final parent = await repo.getById(widget.parentEntryId);
    if (parent != null) {
      try {
        final map = jsonDecode(parent.payloadJson) as Map<String, dynamic>;
        _parentName = map['name'] as String?;
      } catch (_) {}
    }

    final list = await repo.listChildrenOfParent(widget.parentEntryId);
    if (mounted) {
      setState(() {
        _children = list;
        loading = false;
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
    // Dispose all controllers (both existing and pending)
    for (final t in _controllers.values) {
      t.dispose();
    }
    _controllers.clear();
    super.dispose();
  }

  Future<void> _onSave({required bool closeAfter}) async {
    await safeSave(
      closeAfter: closeAfter,
      onSave: () async {
        final repo = ref.read(entriesRepositoryProvider);
        final registry = ref.read(widgetRegistryProvider);
        if (repo == null) return;

        // Get parent entry to extract targetAt for new entries
        final parent = await repo.getById(widget.parentEntryId);
        if (parent == null) return;

        // Mark parent as static on first override
        await repo.update(widget.parentEntryId, {'is_static': 1});

        // 1. Delete pending deletes
        for (final id in _pendingDeletes) {
          await repo.delete(id);
        }

        // 2. Create pending adds
        for (final kind in _pendingAdds) {
          final ctrl = _controllers['pending_${kind.id}']!;
          final val = parseDouble(ctrl.text) ?? 0.0;
          await repo.create(
            widgetKind: kind.id,
            targetAtLocal: DateTime.fromMillisecondsSinceEpoch(
              parent.targetAt,
              isUtc: true,
            ).toLocal(),
            payload: {'amount': val, 'unit': kind.unit},
            showInCalendar: false,
            sourceEntryId: widget.parentEntryId,
          );
        }

        // 3. Update existing children (excluding deleted ones)
        for (final c in _children) {
          if (_pendingDeletes.contains(c.id)) continue;
          final ctrl = _controllers[c.id]!;
          final val = parseDouble(ctrl.text) ?? 0.0;
          try {
            final map = jsonDecode(c.payloadJson) as Map<String, dynamic>;
            // preserve unit if present, or derive from kind metadata
            final unit =
                (map['unit'] as String?) ?? (registry.byId(c.widgetKind)?.unit);
            final newPayload = <String, Object?>{'amount': val};
            if (unit != null) newPayload['unit'] = unit;
            await repo.update(c.id, {'payload_json': jsonEncode(newPayload)});
          } catch (_) {
            await repo.update(c.id, {
              'payload_json': jsonEncode({
                'amount': val,
                'unit': registry.byId(c.widgetKind)?.unit,
              }),
            });
          }
        }

        // Clear pending changes after successful save
        _pendingAdds.clear();
        _pendingDeletes.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Updated components (instance is now Static)'),
            ),
          );
        }
      },
    );
  }

  Future<void> _addComponent() async {
    final registry = ref.read(widgetRegistryProvider);

    // Get all available kinds
    final allKinds = registry.kinds.toList();
    // Filter out kinds that already exist in children or pending adds
    final existingKindIds = _children.map((c) => c.widgetKind).toSet();
    final pendingKindIds = _pendingAdds.map((k) => k.id).toSet();
    final usedKindIds = {...existingKindIds, ...pendingKindIds};
    final availableKinds = allKinds
        .where((k) => !usedKindIds.contains(k.id))
        .toList();

    if (availableKinds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All nutrients already added')),
      );
      return;
    }

    final picked = await showDialog<WidgetKind?>(
      context: context,
      builder: (ctx) => AddKindDialog(kinds: availableKinds),
    );
    if (picked == null) return;

    // Add to pending (no DB write yet)
    setState(() {
      _pendingAdds.add(picked);
      // Create controller for the pending add (use kind.id as key)
      _controllers['pending_${picked.id}'] = TextEditingController(text: '0');
    });
  }

  void _removeExisting(String entryId) {
    setState(() {
      _pendingDeletes.add(entryId);
    });
  }

  void _removePending(WidgetKind kind) {
    setState(() {
      _pendingAdds.remove(kind);
      // Dispose and remove controller
      _controllers['pending_${kind.id}']?.dispose();
      _controllers.remove('pending_${kind.id}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(widgetRegistryProvider);

    return buildShell(
      context: context,
      title: 'Edit ${_parentName ?? 'components'}',
      onSave: ({required closeAfter}) => _onSave(closeAfter: closeAfter),
      content: Column(
        children: [
          () {
            // Build combined list: existing (minus deleted) + pending adds
            final visibleChildren = _children
                .where((c) => !_pendingDeletes.contains(c.id))
                .toList();
            final totalCount = visibleChildren.length + _pendingAdds.length;

            if (totalCount == 0) {
              return const SizedBox(
                height: 100,
                child: Center(child: Text('No components yet')),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: totalCount,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                // First show existing children, then pending adds
                if (i < visibleChildren.length) {
                  // Existing child
                  final e = visibleChildren[i];
                  final kind = registry.byId(e.widgetKind);
                  final icon = kind?.icon ?? Icons.circle;
                  final color =
                      kind?.accentColor ??
                      Theme.of(context).colorScheme.primary;
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 100,
                          child: TextFormField(
                            controller: ctrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              hintText: '0',
                              isDense: true,
                            ),
                            validator: ValidationRules.nonNegativeAmount,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _removeExisting(e.id),
                        ),
                      ],
                    ),
                  );
                } else {
                  // Pending add
                  final pendingIndex = i - visibleChildren.length;
                  final kind = _pendingAdds[pendingIndex];
                  final icon = kind.icon;
                  final color = kind.accentColor;
                  final unit = kind.unit;
                  final ctrl = _controllers['pending_${kind.id}']!;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      child: Icon(icon, size: 18),
                    ),
                    title: Text(kind.displayName),
                    subtitle: Text(
                      unit.isEmpty ? '(new)' : '(new) Unit: $unit',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 100,
                          child: TextFormField(
                            controller: ctrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              hintText: '0',
                              isDense: true,
                            ),
                            validator: ValidationRules.nonNegativeAmount,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _removePending(kind),
                        ),
                      ],
                    ),
                  );
                }
              },
            );
          }(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: loading ? null : _addComponent,
              icon: const Icon(Icons.add),
              label: const Text('Add nutrient'),
            ),
          ),
        ],
      ),
    );
  }
}

// Remove _AddNutrientDialog class

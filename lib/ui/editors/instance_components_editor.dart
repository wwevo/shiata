import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/entries_repository.dart';
import '../../domain/widgets/registry.dart';

class InstanceComponentsEditorPage extends ConsumerStatefulWidget {
  const InstanceComponentsEditorPage({super.key, required this.parentEntryId});
  final String parentEntryId;

  @override
  ConsumerState<InstanceComponentsEditorPage> createState() => _InstanceComponentsEditorPageState();
}

class _InstanceComponentsEditorPageState extends ConsumerState<InstanceComponentsEditorPage> {
  bool _loading = true;
  List<EntryRecord> _children = const [];
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(entriesRepositoryProvider);
    if (repo == null) return;
    final list = await repo.listChildrenOfParent(widget.parentEntryId);
    setState(() {
      _children = list;
      _loading = false;
    });
    // initialize controllers
    for (final c in list) {
      try {
        final map = jsonDecode(c.payloadJson) as Map<String, dynamic>;
        final amount = (map['amount'] as num?)?.toInt() ?? 0;
        _controllers[c.id] = TextEditingController(text: amount.toString());
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

  Future<void> _save() async {
    final repo = ref.read(entriesRepositoryProvider);
    final registry = ref.read(widgetRegistryProvider);
    if (repo == null) return;
    // Mark parent as static on first override
    await repo.update(widget.parentEntryId, {'is_static': 1});
    // Update each child payload amount
    for (final c in _children) {
      final ctrl = _controllers[c.id]!;
      final val = int.tryParse(ctrl.text.trim()) ?? 0;
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
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(widgetRegistryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit components (Static)'),
        actions: [
          IconButton(onPressed: _loading ? null : _save, icon: const Icon(Icons.check))
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
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
                  leading: CircleAvatar(backgroundColor: color, foregroundColor: Colors.white, child: Icon(icon, size: 18)),
                  title: Text(kind?.displayName ?? e.widgetKind),
                  subtitle: Text(unit.isEmpty ? '' : 'Unit: $unit'),
                  trailing: SizedBox(
                    width: 120,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ctrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: '0'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(''),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

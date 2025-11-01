import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/kinds_repository.dart';
import '../../data/repo/kind_service.dart';
import '../../data/repo/import_export_service.dart';

Future<void> _exportJson(BuildContext context, WidgetRef ref) async {
  final svc = ref.read(importExportServiceProvider);
  if (svc == null) return;
  try {
    final bundle = await svc.exportBundle();
    final encoder = const JsonEncoder.withIndent('  ');
    final text = encoder.convert(bundle);
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Export (JSON)')
,
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: SelectableText(text),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                }
              },
              child: const Text('Copy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
  }
}

Future<void> _importJson(BuildContext context, WidgetRef ref) async {
  final svc = ref.read(importExportServiceProvider);
  if (svc == null) return;
  final controller = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Import (JSON)'),
        content: SizedBox(
          width: 600,
          child: TextField(
            controller: controller,
            maxLines: 16,
            decoration: const InputDecoration(hintText: '{"version":1, ...}'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Continue')),
        ],
      );
    },
  );
  if (confirmed != true) return;
  try {
    final result = await svc.importBundle(controller.text);
    if (!context.mounted) return;
    final msg = 'Imported: ${result.kindsUpserted} kinds, ${result.productsUpserted} products, ${result.componentsWritten} components${result.warnings.isEmpty ? '' : '\nWarnings: ${result.warnings.length}'}';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import result'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Text(result.warnings.isEmpty ? msg : ('$msg\n\n${result.warnings.join('\n')}')),
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
        ],
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
  }
}

class KindsPage extends ConsumerWidget {
  const KindsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kindsAsync = ref.watch(kindsListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kinds'),
        actions: [
          IconButton(
            tooltip: 'Add kind',
            icon: const Icon(Icons.add),
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (ctx) => KindEditorDialog(),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'export':
                  await _exportJson(context, ref);
                  break;
                case 'import':
                  await _importJson(context, ref);
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'export', child: Text('Export (JSON)')),
              const PopupMenuItem(value: 'import', child: Text('Import (JSON)')),
            ],
          ),
        ],
      ),
      body: kindsAsync.when(
        data: (kinds) {
          if (kinds.isEmpty) {
            return const Center(child: Text('No kinds yet'));
          }
          return ListView.builder(
            itemCount: kinds.length,
            itemBuilder: (ctx, i) {
              final k = kinds[i];
              final icon = _resolveIcon(k.icon, Icons.category);
              final color = Color(k.color ?? 0xFF607D8B);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    child: Icon(icon, color: Colors.white),
                  ),
                  title: Text(k.name),
                  subtitle: Text('${k.unit}  •  min ${k.min}  •  max ${k.max}${k.defaultShowInCalendar ? '  •  calendar' : ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          await showDialog(
                            context: context,
                            builder: (_) => KindEditorDialog(existing: k),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final svc = ref.read(kindServiceProvider);
                          if (svc == null) return;
                          // Load usage
                          final usage = await svc.getUsage(k.id);
                          if (usage == null) return; // kind not found
                          if (!context.mounted) return;
                          bool removeFromProducts = usage.productsUsing.isNotEmpty;
                          bool deleteDirectEntries = usage.directEntriesCount > 0;
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (_) {
                              return StatefulBuilder(builder: (ctx, setState) {
                                return AlertDialog(
                                  title: const Text('Delete kind'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('"${k.name}"'),
                                      const SizedBox(height: 8),
                                      if (usage.productsUsing.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: Text('Used by ${usage.productsUsing.length} product(s): ${usage.productsUsing.map((p) => p.name).join(', ')}'),
                                        ),
                                      if (usage.directEntriesCount > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: Text('${usage.directEntriesCount} direct calendar instance(s)'),
                                        ),
                                      if (usage.productsUsing.isEmpty && usage.directEntriesCount == 0)
                                        const Text('This kind is not used.'),
                                      const Divider(),
                                      CheckboxListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: const Text('Remove from product templates and update existing entries'),
                                        value: removeFromProducts,
                                        onChanged: (v) => setState(() => removeFromProducts = v ?? false),
                                      ),
                                      CheckboxListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: const Text('Delete direct calendar instances of this kind'),
                                        value: deleteDirectEntries,
                                        onChanged: (v) => setState(() => deleteDirectEntries = v ?? false),
                                      ),
                                      if ((usage.productsUsing.isNotEmpty || usage.directEntriesCount > 0) && !(removeFromProducts || deleteDirectEntries))
                                        const Padding(
                                          padding: EdgeInsets.only(top: 4),
                                          child: Text('Select at least one option to proceed, because the kind is in use.', style: TextStyle(color: Colors.redAccent)),
                                        ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                    FilledButton(
                                      onPressed: ((usage.productsUsing.isNotEmpty || usage.directEntriesCount > 0) && !(removeFromProducts || deleteDirectEntries))
                                          ? null
                                          : () => Navigator.of(ctx).pop(true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                );
                              });
                            },
                          ) ?? false;
                          if (!confirmed) return;
                          try {
                            final snap = await svc.deleteKindWithSideEffects(
                              kindId: k.id,
                              removeFromProducts: removeFromProducts,
                              deleteDirectEntries: deleteDirectEntries,
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Deleted ${k.name}'),
                                action: snap == null
                                    ? null
                                    : SnackBarAction(
                                        label: 'UNDO',
                                        onPressed: () async {
                                          await svc.undoKindDeletion(snap);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reverted kind deletion')));
                                          }
                                        },
                                      ),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not delete kind: ${e.toString()}')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error loading kinds')),
      ),
    );
  }
}

class KindEditorDialog extends ConsumerStatefulWidget {
  const KindEditorDialog({super.key, this.existing});
  final KindDef? existing;

  @override
  ConsumerState<KindEditorDialog> createState() => _KindEditorDialogState();
}

class _KindEditorDialogState extends ConsumerState<KindEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _id;
  late final TextEditingController _name;
  late String _unit;
  late int _precision;
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
    _precision = e?.precision ?? 0;
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
              DropdownButtonFormField<int>(
                initialValue: _precision,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Precision: 0 (integer)')),
                  DropdownMenuItem(value: 2, child: Text('Precision: 2 (0.01)')),
                ],
                onChanged: (v) => setState(() => _precision = v ?? _precision),
                decoration: const InputDecoration(labelText: 'Precision (decimal places)'),
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
              precision: _precision,
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

IconData _resolveIcon(String? name, IconData fallback) {
  switch (name) {
    case 'fitness_center':
      return Icons.fitness_center;
    case 'opacity':
      return Icons.opacity;
    case 'rice_bowl':
      return Icons.rice_bowl;
    case 'battery_charging_full':
      return Icons.battery_charging_full;
    case 'blur_on':
      return Icons.blur_on;
    case 'bolt':
      return Icons.bolt;
    case 'circle':
      return Icons.circle;
    case 'hexagon':
      return Icons.hexagon;
    case 'science':
      return Icons.science;
    case 'visibility':
      return Icons.visibility;
    case 'medical_information':
      return Icons.medical_information;
    case 'local_florist':
      return Icons.local_florist;
    case 'wb_sunny':
      return Icons.wb_sunny;
    case 'eco':
      return Icons.eco;
    case 'grass':
      return Icons.grass;
    default:
      return fallback;
  }
}

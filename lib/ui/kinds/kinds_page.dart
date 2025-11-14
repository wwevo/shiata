import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/import_export_service.dart';
import '../../data/repo/kind_service.dart';
import '../editors/kind_template_editor_dialog.dart';
import '../widgets/bottom_controls.dart';

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
                builder: (ctx) => KindTemplateEditorDialog(),
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
                            builder: (_) => KindTemplateEditorDialog(existing: k),
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
      bottomNavigationBar: const BottomControls(),
    );
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

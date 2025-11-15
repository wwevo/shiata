import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/kind_service.dart';
import '../editors/kind_template_editor_dialog.dart';
import '../widgets/icon_resolver.dart';

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
              final icon = resolveIcon(k.icon, Icons.category);
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
    );
  }
}

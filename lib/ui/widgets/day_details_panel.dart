import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/entries_repository.dart';
import '../../data/repo/product_service.dart';
import '../../data/repo/recipe_service.dart';
import '../../domain/widgets/registry.dart';
import '../../utils/formatters.dart';
// import '../editors/protein_editor.dart';
// import '../editors/fat_editor.dart';
// import '../editors/carbohydrate_editor.dart';
import '../editors/kind_instance_editor_dialog.dart';
import '../editors/product_instance_components_editor_dialog.dart';
import '../editors/product_instance_editor_dialog.dart';
import '../main_screen_providers.dart';
import 'action_sheet_helpers.dart';
import 'nested_product_parent_row.dart';
import 'product_child_row.dart';

class DayDetailsPanel extends ConsumerWidget {
  const DayDetailsPanel({super.key});

  String _productTitleFromPayload(EntryRecord e) {
    try {
      final map = jsonDecode(e.payloadJson) as Map<String, dynamic>;
      final name = (map['name'] as String?) ?? 'Product';
      final grams = (map['grams'] as num?)?.toInt();
      if (grams != null) {
        return '$name • $grams g';
      }
      return name;
    } catch (_) {
      return 'Product';
    }
  }

  String _recipeTitleFromPayload(EntryRecord e) {
    try {
      final map = jsonDecode(e.payloadJson) as Map<String, dynamic>;
      final name = (map['name'] as String?) ?? 'Recipe';
      return name;
    } catch (_) {
      return 'Recipe';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDayProvider);
    final repo = ref.watch(entriesRepositoryProvider);
    final registry = ref.watch(widgetRegistryProvider);
    if (selected == null || repo == null) {
      // Hint area
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Tap a day to see details',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }

    return StreamBuilder<List<EntryRecord>>(
      stream: repo.watchByDay(selected),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <EntryRecord>[];
        // Parents/standalone are entries without a source; children have a source_entry_id
        final entries = all.where((e) => e.sourceEntryId == null).toList();
        final childrenByParent = <String, List<EntryRecord>>{};
        for (final c in all) {
          if (c.sourceEntryId != null) {
            (childrenByParent[c.sourceEntryId!] ??= []).add(c);
          }
        }
        if (entries.isEmpty) {
          // Empty state: show date and a single Add button that opens the Create Action Sheet
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (ctx) {
                    final handed = ref.watch(handednessProvider);
                    final dateText = Expanded(
                      child: Text(
                        '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    );
                    final addBtn = IconButton(
                      tooltip: 'Add',
                      onPressed: () =>
                          showCreateActionSheet(context, ref, selected),
                      icon: const Icon(Icons.add_circle_outline),
                    );
                    return Row(
                      children: handed == Handedness.left
                          ? [addBtn, const SizedBox(width: 8), dateText]
                          : [dateText, addBtn],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'No entries for this day yet',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Builder(
                builder: (ctx) {
                  final handed = ref.watch(handednessProvider);
                  final dateText = Expanded(
                    child: Text(
                      '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  );
                  final addBtn = IconButton(
                    tooltip: 'Add',
                    onPressed: () =>
                        showCreateActionSheet(context, ref, selected),
                    icon: const Icon(Icons.add_circle_outline),
                  );
                  return Row(
                    children: handed == Handedness.left
                        ? [addBtn, const SizedBox(width: 8), dateText]
                        : [dateText, addBtn],
                  );
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: entries.length,
                itemBuilder: (ctx, i) {
                  final e = entries[i];
                  final localTime = DateTime.fromMillisecondsSinceEpoch(
                    e.targetAt,
                    isUtc: true,
                  ).toLocal();
                  final kind = registry.byId(e.widgetKind);
                  final color =
                      kind?.accentColor ??
                      Theme.of(context).colorScheme.primary;
                  IconData icon;
                  Color bg;
                  if (e.widgetKind == 'product') {
                    icon = Icons.shopping_basket;
                    bg = Colors.purple;
                  } else if (e.widgetKind == 'recipe') {
                    icon = Icons.restaurant_menu;
                    bg = Colors.brown;
                  } else {
                    icon = kind?.icon ?? Icons.circle;
                    bg =
                        kind?.accentColor ??
                        Theme.of(context).colorScheme.primary;
                  }
                  final isRecipeParent = (e.widgetKind == 'recipe');
                  final isProductParent = (e.widgetKind == 'product');
                  final isParent = isRecipeParent || isProductParent;
                  // Derive short summary from payload
                  String summary = '';
                  try {
                    final map =
                        jsonDecode(e.payloadJson) as Map<String, dynamic>;
                    final grams = (map['grams'] as num?)?.toInt();
                    if (grams != null) summary = '$grams g';
                  } catch (_) {}

                  final expandedSet = ref.watch(expandedProductsProvider);
                  final isExpanded = isParent && expandedSet.contains(e.id);
                  Widget parentRow = Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      onTap: isParent ? () {
                        final set = {...expandedSet};
                        if (isExpanded) {
                          set.remove(e.id);
                        } else {
                          set.add(e.id);
                        }
                        ref.read(expandedProductsProvider.notifier).state = set;
                      } : null,
                    leading: CircleAvatar(
                      backgroundColor: bg,
                      foregroundColor: Colors.white,
                      child: Icon(icon, size: 18),
                    ),
                    title: Text(
                      isProductParent
                          ? _productTitleFromPayload(e)
                          : isRecipeParent
                          ? _recipeTitleFromPayload(e)
                          : '${kind?.displayName ?? e.widgetKind} • ${summary.isEmpty ? '—' : summary}',
                    ),
                    subtitle: Row(
                      children: [
                        Text(fmtTime(localTime)),
                        if (!isProductParent && !e.showInCalendar) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.event_busy,
                            size: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Hidden',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isProductParent)
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () async {
                              await showDialog(
                                context: ctx,
                                builder: (_) =>
                                    ProductEditorDialog(entryId: e.id),
                              );
                            },
                          )
                        else if (!isRecipeParent)
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () {
                              final k = registry.byId(e.widgetKind);
                              if (k != null) {
                                showDialog(
                                  context: context,
                                  builder: (_) => KindInstanceEditorDialog(kind: k, entryId: e.id),
                                );
                              }
                            },
                          ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete entry?'),
                                content: Text(
                                  isProductParent
                                      ? 'This will remove the product entry and its components. You can undo from the snackbar.'
                                      : 'This will remove the entry. You can undo from the snackbar.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm != true) return;
                            if (isProductParent) {
                              // Capture data for undo before deleting
                              final original = e;
                              Map<String, Object?> parentPayload = const {};
                              String? productId;
                              int grams = 0;
                              bool staticFlag = false;
                              try {
                                final map =
                                    jsonDecode(original.payloadJson)
                                        as Map<String, dynamic>;
                                parentPayload = map;
                                productId = map['product_id'] as String?;
                                grams = (map['grams'] as num?)?.toInt() ?? 0;
                              } catch (_) {}
                              staticFlag = original.isStatic;
                              final targetLocal =
                                  DateTime.fromMillisecondsSinceEpoch(
                                    original.targetAt,
                                    isUtc: true,
                                  ).toLocal();
                              final service = ref.read(productServiceProvider);
                              await ref
                                  .read(entriesRepositoryProvider)!
                                  .deleteChildrenOfParent(original.id);
                              await repo.delete(original.id);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Product deleted'),
                                  action: SnackBarAction(
                                    label: 'UNDO',
                                    onPressed: () async {
                                      try {
                                        if (service != null &&
                                            productId != null &&
                                            grams > 0) {
                                          await service.createProductEntry(
                                            productId: productId,
                                            productGrams: grams,
                                            targetAtLocal: targetLocal,
                                            isStatic: staticFlag,
                                          );
                                        } else {
                                          // Fallback: recreate only the parent row
                                          await repo.create(
                                            widgetKind: original.widgetKind,
                                            targetAtLocal: targetLocal,
                                            payload: parentPayload,
                                            showInCalendar:
                                                original.showInCalendar,
                                            schemaVersion:
                                                original.schemaVersion,
                                          );
                                        }
                                      } catch (_) {}
                                    },
                                  ),
                                ),
                              );
                            } else if (isRecipeParent) {
                              // Snapshot overrides for Undo
                              String recipeId = '';
                              try {
                                final map =
                                    jsonDecode(e.payloadJson)
                                        as Map<String, dynamic>;
                                recipeId = (map['recipe_id'] as String?) ?? '';
                              } catch (_) {}
                              final kindOverrides = <String, double>{};
                              final productOverrides = <String, int>{};
                              final directChildren =
                                  childrenByParent[e.id] ??
                                  const <EntryRecord>[];
                              for (final c in directChildren) {
                                if (c.widgetKind == 'product') {
                                  try {
                                    final pm =
                                        jsonDecode(c.payloadJson)
                                            as Map<String, dynamic>;
                                    final grams = (pm['grams'] as num?)
                                        ?.toInt();
                                    if (grams != null) {
                                      productOverrides[(pm['product_id']
                                                  as String?) ??
                                              c.id] =
                                          grams;
                                    }
                                  } catch (_) {}
                                  // Also delete grandchildren (nutrients under this product)
                                  await repo.deleteChildrenOfParent(c.id);
                                  await repo.delete(c.id);
                                } else {
                                  try {
                                    final km =
                                        jsonDecode(c.payloadJson)
                                            as Map<String, dynamic>;
                                    final amt = (km['amount'] as num?)
                                        ?.toDouble();
                                    if (amt != null) {
                                      kindOverrides[c.widgetKind] = amt;
                                    }
                                  } catch (_) {}
                                  await repo.delete(c.id);
                                }
                              }
                              final targetLocal =
                                  DateTime.fromMillisecondsSinceEpoch(
                                    e.targetAt,
                                    isUtc: true,
                                  ).toLocal();
                              await repo.delete(e.id);
                              if (!context.mounted) return;
                              final recipeSvc = ref.read(recipeServiceProvider);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Recipe deleted'),
                                  action: SnackBarAction(
                                    label: 'UNDO',
                                    onPressed: () async {
                                      try {
                                        if (recipeSvc != null &&
                                            recipeId.isNotEmpty) {
                                          await recipeSvc.createRecipeEntry(
                                            recipeId: recipeId,
                                            targetAtLocal: targetLocal,
                                            kindOverrides: kindOverrides.isEmpty
                                                ? null
                                                : kindOverrides,
                                            productGramOverrides:
                                                productOverrides.isEmpty
                                                ? null
                                                : productOverrides,
                                            showParentInCalendar: true,
                                          );
                                        }
                                      } catch (_) {}
                                    },
                                  ),
                                ),
                              );
                            } else {
                              // Single entry delete with simple Undo
                              final original = e;
                              await repo.delete(e.id);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Entry deleted'),
                                  action: SnackBarAction(
                                    label: 'UNDO',
                                    onPressed: () async {
                                      final local =
                                          DateTime.fromMillisecondsSinceEpoch(
                                            original.targetAt,
                                            isUtc: true,
                                          ).toLocal();
                                      try {
                                        final payload =
                                            jsonDecode(original.payloadJson)
                                                as Map<String, Object?>;
                                        await repo.create(
                                          widgetKind: original.widgetKind,
                                          targetAtLocal: local,
                                          payload: payload,
                                          showInCalendar:
                                              original.showInCalendar,
                                          schemaVersion: original.schemaVersion,
                                        );
                                      } catch (_) {}
                                    },
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        if (isProductParent)
                          IconButton(
                            tooltip: 'Edit components (make static)'.toString(),
                            icon: const Icon(Icons.tune),
                            onPressed: () async {
/*                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => InstanceComponentsEditorPage(
                                    parentEntryId: e.id,
                                  ),
                                ),
                              );*/
                              await showDialog(
                                context: context,
                                builder: (_) => InstanceComponentsEditorDialog(parentEntryId: e.id),
                              );
                            },
                          ),
                        if (isParent)
                          AnimatedRotation(
                            turns: isExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 120),
                            child: const Icon(Icons.expand_more),
                          )
                        else
                          const Icon(Icons.chevron_right),
                      ],
                    ),
                    ),
                  );

                  if (!isParent || !isExpanded) {
                    return parentRow;
                  }
                  // Render expanded children under the parent
                  final children =
                      childrenByParent[e.id] ?? const <EntryRecord>[];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      parentRow,
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 52,
                          right: 8,
                          bottom: 8,
                        ),
                        child: Column(
                          children: [
                            for (final c in children)
                              if (c.widgetKind == 'product')
                                NestedProductParentRow(
                                  entry: c,
                                  registry: registry,
                                  children:
                                      childrenByParent[c.id] ??
                                      const <EntryRecord>[],
                                  expandedSet: ref.watch(
                                    expandedProductsProvider,
                                  ),
                                )
                              else
                                ProductChildRow(entry: c, registry: registry),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

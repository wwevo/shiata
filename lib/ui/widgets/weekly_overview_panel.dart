import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/entries_repository.dart';
import '../../data/repo/product_service.dart';
import '../../data/repo/recipe_service.dart';
import '../../domain/widgets/registry.dart';
import '../editors/kind_instance_editor_dialog.dart';
import '../editors/product_instance_components_editor_dialog.dart';
import '../editors/product_instance_editor_dialog.dart';
import '../main_screen_providers.dart';
import '../ux_config.dart';
import 'nested_product_parent_row.dart';
import 'product_child_row.dart';

// Provider for selected kinds filter (which kinds to show in pie chart)
final selectedKindsForChartProvider = StateProvider<Set<String>>((_) => {'protein', 'fat', 'carbohydrate'});

/// Weekly overview panel showing:
/// - Filter chips to select which kinds to include in pie chart
/// - Pie chart of selected nutrients for last 7 days
/// - Scrollable list of all entries from last 7 days
class WeeklyOverviewPanel extends ConsumerWidget {
  const WeeklyOverviewPanel({super.key});

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(entriesRepositoryProvider);
    final registry = ref.watch(widgetRegistryProvider);
    final theme = Theme.of(context);
    final uxConfig = ref.watch(uxConfigProvider);

    if (repo == null) {
      return const Center(child: Text('Repository not available'));
    }

    // Calculate date range: last 7 days (inclusive of today)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = today.subtract(const Duration(days: 6)); // 7 days total including today
    final tomorrow = today.add(const Duration(days: 1)); // End date is exclusive, so we need tomorrow to include today

    final selectedKinds = ref.watch(selectedKindsForChartProvider);

    return StreamBuilder<Map<DateTime, List<EntryRecord>>>(
      stream: repo.watchByDayRange(sevenDaysAgo, tomorrow, onlyShowInCalendar: false),
      builder: (context, snapshot) {
        final entriesMap = snapshot.data ?? const <DateTime, List<EntryRecord>>{};

        // Flatten map to list
        final allEntries = <EntryRecord>[];
        for (final dayEntries in entriesMap.values) {
          allEntries.addAll(dayEntries);
        }

        // Filter only parent entries (no children) for display list
        final parentEntries = allEntries.where((e) => e.sourceEntryId == null).toList()
          ..sort((a, b) => b.targetAt.compareTo(a.targetAt)); // Most recent first

        // Build children map for nested entries
        final childrenByParent = <String, List<EntryRecord>>{};
        for (final c in allEntries) {
          if (c.sourceEntryId != null) {
            (childrenByParent[c.sourceEntryId!] ??= []).add(c);
          }
        }

        // Aggregate ALL amounts (regardless of selection) to determine which kinds have data
        final allAmounts = <String, double>{};
        for (final e in allEntries) {
          if (e.widgetKind == 'product' || e.widgetKind == 'recipe') continue;

          try {
            final map = jsonDecode(e.payloadJson) as Map<String, dynamic>;
            final amount = (map['amount'] as num?)?.toDouble() ?? 0.0;
            allAmounts[e.widgetKind] = (allAmounts[e.widgetKind] ?? 0.0) + amount;
          } catch (_) {}
        }

        // Only show filter chips for kinds that actually have data in the last 7 days
        final availableKindIds = allAmounts.keys.toSet();
        final allKinds = registry.all
            .where((k) => availableKindIds.contains(k.id))
            .toList();

        // Aggregate amounts for SELECTED kinds only (for the chart)
        final aggregated = <String, double>{};
        for (final kindId in selectedKinds) {
          if (allAmounts.containsKey(kindId)) {
            aggregated[kindId] = allAmounts[kindId]!;
          }
        }

        final chartData = aggregated;

        return Column(
          key: ValueKey(selectedKinds.hashCode), // Force rebuild when filter changes
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filter chips for kind selection
            if (allKinds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Wrap(
                  spacing: 8,
                  children: allKinds.map((kind) {
                    final isSelected = selectedKinds.contains(kind.id);
                    return FilterChip(
                      label: Text(kind.displayName),
                      selected: isSelected,
                      onSelected: (selected) {
                        final newSet = {...selectedKinds};
                        if (selected) {
                          newSet.add(kind.id);
                        } else {
                          newSet.remove(kind.id);
                        }
                        ref.read(selectedKindsForChartProvider.notifier).state = newSet;
                      },
                      avatar: CircleAvatar(
                        backgroundColor: isSelected ? kind.accentColor : Colors.grey,
                        radius: 8,
                      ),
                    );
                  }).toList(),
                ),
              ),
            // Pie chart section
            Container(
              height: uxConfig.topSheet.expandedHeight,
              padding: const EdgeInsets.all(16),
              child: chartData.isEmpty
                  ? Center(
                      child: Text(
                        'No data for last 7 days',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              sections: chartData.entries.map((entry) {
                                final kind = registry.byId(entry.key);
                                final color = kind?.accentColor ?? theme.colorScheme.primary;
                                final unit = kind?.unit ?? '';
                                return PieChartSectionData(
                                  value: entry.value,
                                  title: '${entry.value.toStringAsFixed(0)}$unit',
                                  color: color,
                                  radius: 100,
                                  titleStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                );
                              }).toList(),
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: chartData.entries.map((entry) {
                            final kind = registry.byId(entry.key);
                            final color = kind?.accentColor ?? theme.colorScheme.primary;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    kind?.displayName ?? entry.key,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
            ),
            const Divider(height: 1),
            // Header for list
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Last 7 days (${parentEntries.length} entries)',
                style: theme.textTheme.titleMedium,
              ),
            ),
            // List of all entries
            Expanded(
              child: parentEntries.isEmpty
                  ? Center(
                      child: Text(
                        'No entries in the last 7 days',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: parentEntries.length,
                      itemBuilder: (ctx, i) {
                        final e = parentEntries[i];
                        final localTime = DateTime.fromMillisecondsSinceEpoch(
                          e.targetAt,
                          isUtc: true,
                        ).toLocal();
                        final kind = registry.byId(e.widgetKind);

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
                          bg = kind?.accentColor ?? theme.colorScheme.primary;
                        }

                        final isRecipeParent = (e.widgetKind == 'recipe');
                        final isProductParent = (e.widgetKind == 'product');
                        final isParent = isRecipeParent || isProductParent;

                        String title = kind?.displayName ?? e.widgetKind;
                        String summary = '';

                        try {
                          final map = jsonDecode(e.payloadJson) as Map<String, dynamic>;

                          // Extract name for products and recipes
                          if (e.widgetKind == 'product') {
                            title = (map['name'] as String?) ?? 'Product';
                            final grams = (map['grams'] as num?)?.toInt();
                            if (grams != null) summary = '$grams g';
                          } else if (e.widgetKind == 'recipe') {
                            title = (map['name'] as String?) ?? 'Recipe';
                          } else {
                            // For kinds, show amount
                            final amount = (map['amount'] as num?)?.toDouble();
                            if (amount != null) {
                              summary = '${amount.toStringAsFixed(1)} ${kind?.unit ?? ''}';
                            }
                          }
                        } catch (_) {}

                        final expandedSet = ref.watch(expandedProductsProvider);
                        final isExpanded = isParent && expandedSet.contains(e.id);

                        Widget parentRow = Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            onTap: () {
                              if (isParent) {
                                final set = {...expandedSet};
                                if (isExpanded) {
                                  set.remove(e.id);
                                } else {
                                  set.add(e.id);
                                }
                                ref.read(expandedProductsProvider.notifier).state = set;
                                return;
                              }
                              // Open editor for non-parent kinds
                              final k = registry.byId(e.widgetKind);
                              if (k != null) {
                                showDialog(
                                  context: context,
                                  builder: (_) => KindInstanceEditorDialog(kind: k, entryId: e.id),
                                );
                              }
                            },
                            leading: CircleAvatar(
                              backgroundColor: bg,
                              foregroundColor: Colors.white,
                              child: Icon(icon, size: 18),
                            ),
                            title: Text(
                              isProductParent ? '$title ${summary.isNotEmpty ? "• $summary" : ""}' :
                                isRecipeParent ? title :
                                '$title ${summary.isNotEmpty ? "• $summary" : ""}',
                              style: theme.textTheme.bodyLarge,
                            ),
                            subtitle: Text(
                              '${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')} ${_fmtTime(localTime)}',
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
                                        builder: (_) => ProductEditorDialog(entryId: e.id),
                                      );
                                    },
                                  ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _deleteEntry(context, ref, e, isProductParent, isRecipeParent, childrenByParent, repo),
                                ),
                                if (isProductParent)
                                  IconButton(
                                    tooltip: 'Edit components',
                                    icon: const Icon(Icons.tune),
                                    onPressed: () async {
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
                        final children = childrenByParent[e.id] ?? const <EntryRecord>[];
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
                                        children: childrenByParent[c.id] ?? const <EntryRecord>[],
                                        expandedSet: ref.watch(expandedProductsProvider),
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

  Future<void> _deleteEntry(
    BuildContext context,
    WidgetRef ref,
    EntryRecord e,
    bool isProductParent,
    bool isRecipeParent,
    Map<String, List<EntryRecord>> childrenByParent,
    EntriesRepository repo,
  ) async {
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
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    if (isProductParent) {
      final original = e;
      Map<String, Object?> parentPayload = const {};
      String? productId;
      int grams = 0;
      bool staticFlag = false;
      try {
        final map = jsonDecode(original.payloadJson) as Map<String, dynamic>;
        parentPayload = map;
        productId = map['product_id'] as String?;
        grams = (map['grams'] as num?)?.toInt() ?? 0;
      } catch (_) {}
      staticFlag = original.isStatic;
      final targetLocal = DateTime.fromMillisecondsSinceEpoch(
        original.targetAt,
        isUtc: true,
      ).toLocal();
      final service = ref.read(productServiceProvider);
      await ref.read(entriesRepositoryProvider)!.deleteChildrenOfParent(original.id);
      await repo.delete(original.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Product deleted'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () async {
              try {
                if (service != null && productId != null && grams > 0) {
                  await service.createProductEntry(
                    productId: productId,
                    productGrams: grams,
                    targetAtLocal: targetLocal,
                    isStatic: staticFlag,
                  );
                } else {
                  await repo.create(
                    widgetKind: original.widgetKind,
                    targetAtLocal: targetLocal,
                    payload: parentPayload,
                    showInCalendar: original.showInCalendar,
                    schemaVersion: original.schemaVersion,
                  );
                }
              } catch (_) {}
            },
          ),
        ),
      );
    } else if (isRecipeParent) {
      String recipeId = '';
      try {
        final map = jsonDecode(e.payloadJson) as Map<String, dynamic>;
        recipeId = (map['recipe_id'] as String?) ?? '';
      } catch (_) {}
      final kindOverrides = <String, double>{};
      final productOverrides = <String, int>{};
      final directChildren = childrenByParent[e.id] ?? const <EntryRecord>[];
      for (final c in directChildren) {
        if (c.widgetKind == 'product') {
          try {
            final pm = jsonDecode(c.payloadJson) as Map<String, dynamic>;
            final grams = (pm['grams'] as num?)?.toInt();
            if (grams != null) {
              productOverrides[(pm['product_id'] as String?) ?? c.id] = grams;
            }
          } catch (_) {}
          await repo.deleteChildrenOfParent(c.id);
          await repo.delete(c.id);
        } else {
          try {
            final km = jsonDecode(c.payloadJson) as Map<String, dynamic>;
            final amt = (km['amount'] as num?)?.toDouble();
            if (amt != null) {
              kindOverrides[c.widgetKind] = amt;
            }
          } catch (_) {}
          await repo.delete(c.id);
        }
      }
      final targetLocal = DateTime.fromMillisecondsSinceEpoch(
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
                if (recipeSvc != null && recipeId.isNotEmpty) {
                  await recipeSvc.createRecipeEntry(
                    recipeId: recipeId,
                    targetAtLocal: targetLocal,
                    kindOverrides: kindOverrides.isEmpty ? null : kindOverrides,
                    productGramOverrides: productOverrides.isEmpty ? null : productOverrides,
                    showParentInCalendar: true,
                  );
                }
              } catch (_) {}
            },
          ),
        ),
      );
    } else {
      final original = e;
      await repo.delete(e.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Entry deleted'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () async {
              final local = DateTime.fromMillisecondsSinceEpoch(
                original.targetAt,
                isUtc: true,
              ).toLocal();
              try {
                final payload = jsonDecode(original.payloadJson) as Map<String, Object?>;
                await repo.create(
                  widgetKind: original.widgetKind,
                  targetAtLocal: local,
                  payload: payload,
                  showInCalendar: original.showInCalendar,
                  schemaVersion: original.schemaVersion,
                );
              } catch (_) {}
            },
          ),
        ),
      );
    }
  }
}

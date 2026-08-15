import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/entries_repository.dart';
import '../../domain/widgets/registry.dart';
import '../../utils/formatters.dart';
import 'entry_list_item_factory.dart';

// Provider for selected kinds filter (which kinds to show in pie chart)
final selectedKindsForChartProvider = StateProvider<Set<String>>(
  (_) => {'protein', 'fat', 'carbohydrate'},
);

/// Weekly overview panel showing:
/// - Filter chips to select which kinds to include in pie chart
/// - Pie chart of selected kinds for current week (Mon-Sun)
/// - Scrollable list of all entries from current week
class WeeklyOverviewPanel extends ConsumerWidget {
  const WeeklyOverviewPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(entriesRepositoryProvider);
    final registry = ref.watch(widgetRegistryProvider);
    final theme = Theme.of(context);

    if (repo == null) {
      return const Center(child: Text('Repository not available'));
    }

    // Calculate date range: current week (Monday to Sunday)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final nextMonday = monday.add(const Duration(days: 7));

    final selectedKinds = ref.watch(selectedKindsForChartProvider);

    final Stream<dynamic> entriesStream = repo.watchByDayRange(
      monday,
      nextMonday,
      onlyShowInCalendar: false,
    );

    return StreamBuilder<dynamic>(
      stream: entriesStream,
      builder: (context, snapshot) {
        // Handle both Map<DateTime, List<EntryRecord>> and List<EntryRecord>
        List<EntryRecord> allEntries;
        if (snapshot.data is Map<DateTime, List<EntryRecord>>) {
          final entriesMap = snapshot.data as Map<DateTime, List<EntryRecord>>;
          allEntries = [];
          for (final dayEntries in entriesMap.values) {
            allEntries.addAll(dayEntries);
          }
        } else {
          allEntries = (snapshot.data as List<EntryRecord>?) ?? [];
        }

        // Filter only parent entries (no children) for display list
        final parentEntries =
            allEntries.where((e) => e.sourceEntryId == null).toList()..sort(
              (a, b) => b.targetAt.compareTo(a.targetAt),
            ); // Most recent first

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
            allAmounts[e.widgetKind] =
                (allAmounts[e.widgetKind] ?? 0.0) + amount;
          } catch (_) {}
        }

        // Only show filter chips for kinds that actually have data in this week
        final availableKindIds = allAmounts.keys.toSet();

        // Aggregate selected kinds for pie chart
        final selectedAmounts = <String, double>{};
        for (final kindId in selectedKinds) {
          if (allAmounts.containsKey(kindId)) {
            selectedAmounts[kindId] = allAmounts[kindId]!;
          }
        }

        // Normalize values for pie chart (convert mg→g, µg→g)
        final normalizedAmounts = <String, double>{};
        for (final entry in selectedAmounts.entries) {
          final kind = registry.byId(entry.key);
          final unit = kind?.unit ?? '';
          double normalized = entry.value;

          // Normalize to grams for consistent pie chart proportions
          switch (unit) {
            case 'mg':
              normalized = entry.value / 1000;
              break;
            case 'µg':
              normalized = entry.value / 1000000;
              break;
            default:
              normalized = entry.value;
          }

          normalizedAmounts[entry.key] = normalized;
        }

        final total = normalizedAmounts.values.fold(0.0, (sum, v) => sum + v);

        // Compute normalized totals across ALL kinds to know how much of the week is represented
        final normalizedAllAmounts = <String, double>{};
        for (final entry in allAmounts.entries) {
          final kind = registry.byId(entry.key);
          final unit = kind?.unit ?? '';
          double v = entry.value;
          switch (unit) {
            case 'mg':
              v = v / 1000;
              break;
            case 'µg':
              v = v / 1000000;
              break;
            default:
              v = v;
          }
          normalizedAllAmounts[entry.key] = v;
        }

        final totalAll =
            normalizedAllAmounts.values.fold(0.0, (s, v) => s + v);
        final totalSelected = total;
        final displayedPct =
            totalAll == 0 ? 0.0 : (totalSelected / totalAll * 100);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Chart and filter section
            Container(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Filter chips
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: registry.kinds
                          .where((kind) => availableKindIds.contains(kind.id))
                          .map((kind) {
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
                                ref
                                        .read(
                                          selectedKindsForChartProvider
                                              .notifier,
                                        )
                                        .state =
                                    newSet;
                              },
                            );
                          })
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Pie chart or empty message
                  if (normalizedAmounts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        selectedKinds.isEmpty
                            ? 'Select kinds above to see chart'
                            : 'No data for selected kinds',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          // Pie chart with center indicator of share of week
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PieChart(
                                  PieChartData(
                                    sections: normalizedAmounts.entries.map((
                                      entry,
                                    ) {
                                      final kind = registry.byId(entry.key);
                                      final color =
                                          kind?.accentColor ??
                                          theme.colorScheme.primary;

                                      return PieChartSectionData(
                                        value: entry.value,
                                        title: '', // keep center clean
                                        color: color,
                                        radius: 50,
                                      );
                                    }).toList(),
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 28, // create donut
                                    centerSpaceColor: theme.colorScheme.surface,
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${displayedPct.toStringAsFixed(0)}%',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'of week',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Legend
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: normalizedAmounts.entries.map((
                                  entry,
                                ) {
                                  final kind = registry.byId(entry.key);
                                  final color =
                                      kind?.accentColor ??
                                      theme.colorScheme.primary;
                                  final unit = kind?.unit ?? '';

                                  // Display original value (not normalized)
                                  final originalValue =
                                      selectedAmounts[entry.key]!;
                                  final formattedValue = originalValue < 1
                                      ? originalValue.toStringAsFixed(2)
                                      : originalValue.toStringAsFixed(0);

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
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
                                        Expanded(
                                          child: Text(
                                            '${kind?.displayName ?? entry.key}: $formattedValue$unit',
                                            style: theme.textTheme.bodyMedium,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Header for list
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'This week (${fmtDateRange(monday, sunday)}) · ${parentEntries.length} entries',
                style: theme.textTheme.titleMedium,
              ),
            ),
            // List of all entries
            Expanded(
              child: parentEntries.isEmpty
                  ? Center(
                      child: Text(
                        'No entries this week',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: parentEntries.length,
                      itemBuilder: (ctx, i) {
                        return EntryListItemFactory.buildEntry(
                          context: context,
                          ref: ref,
                          entry: parentEntries[i],
                          childrenByParent: childrenByParent,
                          registry: registry,
                          config: EntryListItemConfig.fullDateTime,
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

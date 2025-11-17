import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/entries_repository.dart';
import '../../domain/widgets/registry.dart';
import '../main_screen_providers.dart';
import '../ux_config.dart';
import 'entry_list_item_factory.dart';

// Provider for selected kinds filter (which kinds to show in pie chart)
final selectedKindsForChartProvider = StateProvider<Set<String>>((_) => {'protein', 'fat', 'carbohydrate'});

/// Weekly overview panel showing:
/// - Filter chips to select which kinds to include in pie chart
/// - Pie chart of selected nutrients for last 7 days
/// - Scrollable list of all entries from last 7 days
class WeeklyOverviewPanel extends ConsumerWidget {
  const WeeklyOverviewPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(entriesRepositoryProvider);
    final searchService = ref.watch(searchServiceProvider);
    final searchQuery = ref.watch(searchQueryProvider);
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

    // Use search service if query is present, otherwise use repository directly
    final Stream<dynamic> entriesStream =
        searchQuery.trim().isNotEmpty && searchService != null
            ? searchService.searchEntriesInDateRange(searchQuery, sevenDaysAgo, tomorrow)
            : repo.watchByDayRange(sevenDaysAgo, tomorrow, onlyShowInCalendar: false);

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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Chart and filter section
            Container(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Filter chips
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: uxConfig.kindsForChart
                          .where((kindId) => availableKindIds.contains(kindId))
                          .map((kindId) {
                        final kind = registry.byId(kindId);
                        final isSelected = selectedKinds.contains(kindId);

                        return FilterChip(
                          label: Text(kind?.displayName ?? kindId),
                          selected: isSelected,
                          onSelected: (selected) {
                            final newSet = {...selectedKinds};
                            if (selected) {
                              newSet.add(kindId);
                            } else {
                              newSet.remove(kindId);
                            }
                            ref.read(selectedKindsForChartProvider.notifier).state = newSet;
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Pie chart or empty message
                  if (normalizedAmounts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        selectedKinds.isEmpty
                            ? 'Select nutrients above to see chart'
                            : 'No data for selected nutrients',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          // Pie chart
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: PieChart(
                              PieChartData(
                                sections: normalizedAmounts.entries.map((entry) {
                                  final kind = registry.byId(entry.key);
                                  final color = kind?.accentColor ?? theme.colorScheme.primary;
                                  final percentage = (entry.value / total * 100);

                                  return PieChartSectionData(
                                    value: entry.value,
                                    title: '${percentage.toStringAsFixed(0)}%',
                                    color: color,
                                    radius: 50,
                                    titleStyle: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                  );
                                }).toList(),
                                sectionsSpace: 2,
                                centerSpaceRadius: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Legend
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: normalizedAmounts.entries.map((entry) {
                                  final kind = registry.byId(entry.key);
                                  final color = kind?.accentColor ?? theme.colorScheme.primary;
                                  final unit = kind?.unit ?? '';

                                  // Display original value (not normalized)
                                  final originalValue = selectedAmounts[entry.key]!;
                                  final formattedValue = originalValue < 1
                                      ? originalValue.toStringAsFixed(2)
                                      : originalValue.toStringAsFixed(0);

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

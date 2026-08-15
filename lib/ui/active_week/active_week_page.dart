import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/entries_repository.dart';
import '../../domain/widgets/registry.dart';
// Note: keep local date formatting within this file; no external date helpers needed here.
import '../main_screen_providers.dart';
import '../ux_config.dart';
import '../widgets/action_sheet_helpers.dart';
import '../widgets/entry_list_item_factory.dart';
import '../widgets/weekly_calendar.dart';

// Local state for chart kind selection (scoped to ActiveWeek page)
final selectedKindsForActiveWeekChartProvider = StateProvider<Set<String>>(
  (_) => {'protein', 'fat', 'carbohydrate'},
);

/// ActiveWeekPage: A new page that combines calendar week navigation with
/// a weekly list grouped by day and an inline add control.
///
/// This page is additive and does not alter existing Overview/Calendar pages.
class ActiveWeekPage extends ConsumerWidget {
  const ActiveWeekPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final config = ref.watch(uxConfigProvider);
    final repo = ref.watch(entriesRepositoryProvider);
    final registry = ref.watch(widgetRegistryProvider);
    final anchor = ref.watch(calendarAnchorProvider); // Monday of current week
    final selectedDay = ref.watch(selectedDayProvider);

    if (repo == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final monday = anchor; // already a Monday per provider
    final nextMonday = monday.add(const Duration(days: 7));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));

    final stream = repo.watchByDayRange(
      monday,
      nextMonday,
      onlyShowInCalendar: false,
    );

    DateTime targetForAdd() {
      if (selectedDay != null) return selectedDay;
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }

    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Weekly calendar row (reused)
          SizedBox(
            height: 120,
            child: WeeklyCalendar(grid: config.calendarGrid),
          ),
          const Divider(height: 1),

          // Inline Add control (same flow as Overview plus action)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Add',
                  onPressed: () => showCreateActionSheet(context, ref, targetForAdd()),
                  icon: const Icon(Icons.add_circle_outline),
                ),
                const SizedBox(width: 8),
                Text(
                  'Add to ${_fmtYmd(targetForAdd())}',
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
          ),

          // Week list grouped by day with headers
          Expanded(
            child: StreamBuilder<dynamic>(
              stream: stream,
              builder: (context, snapshot) {
                // Normalize incoming data shape
                final mapByDay = <DateTime, List<EntryRecord>>{};
                final allEntries = <EntryRecord>[];

                if (snapshot.data is Map<DateTime, List<EntryRecord>>) {
                  final m = snapshot.data as Map<DateTime, List<EntryRecord>>;
                  for (final e in m.entries) {
                    final k = DateTime(e.key.year, e.key.month, e.key.day);
                    mapByDay[k] = [...(mapByDay[k] ?? const []), ...e.value];
                    allEntries.addAll(e.value);
                  }
                } else if (snapshot.data is List<EntryRecord>) {
                  final list = snapshot.data as List<EntryRecord>;
                  for (final e in list) {
                    final d = DateTime.fromMillisecondsSinceEpoch(
                      e.targetAt,
                      isUtc: true,
                    ).toLocal();
                    final k = DateTime(d.year, d.month, d.day);
                    (mapByDay[k] ??= []).add(e);
                    allEntries.add(e);
                  }
                }

                // Children map for nested rendering
                final childrenByParent = <String, List<EntryRecord>>{};
                for (final c in allEntries) {
                  final pid = c.sourceEntryId;
                  if (pid != null) {
                    (childrenByParent[pid] ??= []).add(c);
                  }
                }

                // ================= Pie chart aggregation (cut & paste from weekly_overview_panel) =================
                final selectedKinds = ref.watch(
                  selectedKindsForActiveWeekChartProvider,
                );

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

                // Build a flattened list of rows: headers and entries.
                // Skip days that have no entries (as requested).
                final rows = <_RowItem>[];
                for (final day in days) {
                  final key = DateTime(day.year, day.month, day.day);
                  final list = (mapByDay[key] ?? const <EntryRecord>[]).toList();
                  list.sort((a, b) => a.targetAt.compareTo(b.targetAt)); // time asc

                  // Parents only at top level; children are rendered by factory
                  final parents = list.where((e) => e.sourceEntryId == null).toList();
                  if (parents.isEmpty) {
                    // Do not render empty days
                    continue;
                  }

                  rows.add(_RowItem.header(day));
                  for (final p in parents) {
                    rows.add(_RowItem.entry(p));
                  }
                }

                // Build the combined UI: chart + weekly list
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Chart + filters block
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
                                        .read(selectedKindsForActiveWeekChartProvider.notifier)
                                        .state = newSet;
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
                                    ? 'Select kinds above to see chart'
                                    : 'No data for selected kinds',
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
                                          final color =
                                              kind?.accentColor ?? theme.colorScheme.primary;
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
                                          final color =
                                              kind?.accentColor ?? theme.colorScheme.primary;
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

                    // The weekly list itself
                    Expanded(
                      child: ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (ctx, i) {
                          final item = rows[i];
                          switch (item.type) {
                            case _RowType.header:
                              return _DayHeader(date: item.date!);
                            case _RowType.entry:
                              return EntryListItemFactory.buildEntry(
                                context: context,
                                ref: ref,
                                entry: item.entry!,
                                childrenByParent: childrenByParent,
                                registry: registry,
                                config: EntryListItemConfig.dayDetails,
                              );
                          }
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _RowType { header, entry }

class _RowItem {
  final _RowType type;
  final DateTime? date;
  final EntryRecord? entry;
  const _RowItem._(this.type, {this.date, this.entry});
  factory _RowItem.header(DateTime d) => _RowItem._(_RowType.header, date: d);
  factory _RowItem.entry(EntryRecord e) => _RowItem._(_RowType.entry, entry: e);
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date});
  final DateTime date;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final end = date; // single day
    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Text(
        '${_weekdayShort(date.weekday)} ${_fmtYmd(end)}',
        style: theme.textTheme.titleSmall,
      ),
    );
  }

  String _weekdayShort(int w) {
    switch (w) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '';
    }
  }
}

// Local date formatter (YYYY-MM-DD) to avoid dependency on non-existent fmtYmd
String _fmtYmd(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

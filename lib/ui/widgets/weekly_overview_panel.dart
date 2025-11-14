import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/entries_repository.dart';
import '../editors/kind_instance_editor_dialog.dart';
import '../editors/product_instance_editor_dialog.dart';

/// Weekly overview panel showing:
/// - Pie chart of selected nutrients (Protein, Fat, Carbohydrate) for last 7 days
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

    if (repo == null) {
      return const Center(child: Text('Repository not available'));
    }

    // Calculate date range: last 7 days
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = today.subtract(const Duration(days: 6));

    return StreamBuilder<List<EntryRecord>>(
      stream: repo.watchByDayRange(sevenDaysAgo, today),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <EntryRecord>[];

        // Filter only parent entries (no children)
        final parentEntries = entries.where((e) => e.sourceEntryId == null).toList()
          ..sort((a, b) => b.targetAt.compareTo(a.targetAt)); // Most recent first

        // Aggregate amounts for pie chart (Protein, Fat, Carbohydrate)
        final aggregated = <String, double>{};
        for (final e in parentEntries) {
          if (e.widgetKind == 'product' || e.widgetKind == 'recipe') continue;

          try {
            final map = jsonDecode(e.payloadJson) as Map<String, dynamic>;
            final amount = (map['amount'] as num?)?.toDouble() ?? 0.0;
            aggregated[e.widgetKind] = (aggregated[e.widgetKind] ?? 0.0) + amount;
          } catch (_) {}
        }

        // Filter for main macros only
        final mainMacros = <String>['protein', 'fat', 'carbohydrate'];
        final chartData = <String, double>{};
        for (final macro in mainMacros) {
          final val = aggregated[macro] ?? 0.0;
          if (val > 0) chartData[macro] = val;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pie chart section
            Container(
              height: 300,
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
                                return PieChartSectionData(
                                  value: entry.value,
                                  title: '${entry.value.toStringAsFixed(0)}g',
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
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      itemCount: parentEntries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
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

                        String summary = '';
                        try {
                          final map = jsonDecode(e.payloadJson) as Map<String, dynamic>;
                          final amount = (map['amount'] as num?)?.toDouble();
                          final grams = (map['grams'] as num?)?.toInt();
                          if (amount != null) {
                            summary = '${amount.toStringAsFixed(1)} ${kind?.unit ?? ''}';
                          } else if (grams != null) {
                            summary = '$grams g';
                          }
                        } catch (_) {}

                        return ListTile(
                          onTap: () {
                            if (e.widgetKind == 'product') {
                              showDialog(
                                context: context,
                                builder: (_) => ProductEditorDialog(entryId: e.id),
                              );
                            } else if (e.widgetKind != 'recipe') {
                              final k = registry.byId(e.widgetKind);
                              if (k != null) {
                                showDialog(
                                  context: context,
                                  builder: (_) => KindInstanceEditorDialog(kind: k, entryId: e.id),
                                );
                              }
                            }
                          },
                          leading: CircleAvatar(
                            backgroundColor: bg,
                            foregroundColor: Colors.white,
                            child: Icon(icon, size: 18),
                          ),
                          title: Text(
                            kind?.displayName ?? e.widgetKind,
                            style: theme.textTheme.bodyLarge,
                          ),
                          subtitle: Row(
                            children: [
                              Text(
                                '${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')} ${_fmtTime(localTime)}',
                              ),
                              if (summary.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text('• $summary'),
                              ],
                            ],
                          ),
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

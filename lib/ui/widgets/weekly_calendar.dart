import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/entries_repository.dart';
import '../../domain/widgets/registry.dart';
import '../../utils/formatters.dart';
import '../main_screen_providers.dart';
import '../ux_config.dart';

class WeeklyCalendar extends ConsumerWidget {
  const WeeklyCalendar({super.key, required this.grid});

  final CalendarGridConfig grid;

  void _changeRange(WidgetRef ref, DateTime current, int delta) {
    final next = current.add(Duration(days: 7 * delta));
    ref.read(calendarAnchorProvider.notifier).state = next;
    // Keep a selected day always; if selection falls outside new month, pick a sensible default.
    final sel = ref.read(selectedDayProvider);
    if (sel != null) {
      ref.read(selectedDayProvider.notifier).state = sel.add(
        Duration(days: 7 * delta),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch selected day and anchor
    ref.watch(selectedDayProvider);
    final anchor = ref.watch(calendarAnchorProvider);

    final firstCellLocal = anchor;
    // Use UTC for day iteration to avoid DST-related duplicate/missing local dates
    final firstCellUtc = DateTime.utc(
      firstCellLocal.year,
      firstCellLocal.month,
      firstCellLocal.day,
    );
    final daysToShow = grid.columns * grid.rows; // 42

    final repo = ref.watch(entriesRepositoryProvider);
    final registry = ref.watch(widgetRegistryProvider);

    if (repo == null) {
      return const SizedBox.shrink();
    }

    String weekLabel(DateTime start) {
      final end = start.add(const Duration(days: 6));
      return fmtDateRange(start, end);
    }

    // Build responsive grid with aspect ratio matching available space
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridWidth = constraints.maxWidth - grid.padding * 2;
        final gridHeight = 44;
        if (gridWidth <= 0 || gridHeight <= grid.paintMinHeightPx) {
          return const SizedBox.shrink();
        }
        final totalSpacingW = grid.crossAxisSpacing * (grid.columns - 1);
        final totalSpacingH = grid.mainAxisSpacing * (grid.rows - 1);
        final cellWidth = (gridWidth - totalSpacingW) / grid.columns;
        final cellHeight = (gridHeight - totalSpacingH) / grid.rows;
        if (cellWidth <= grid.paintMinCellPx ||
            cellHeight <= grid.paintMinCellPx) {
          return const SizedBox.shrink();
        }
        final aspect = cellWidth / cellHeight;

        // Stream for entries within the visible calendar window (local dates)
        final startLocal = firstCellLocal;
        final endLocal = firstCellLocal.add(Duration(days: daysToShow));

        // The Date-Span header
        final header = SizedBox(
          height: 36,
          child: Padding(
            padding: const EdgeInsets.all(0),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous week',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeRange(ref, anchor, -1),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      weekLabel(anchor),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next week',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeRange(ref, anchor, 1),
                ),
              ],
            ),
          ),
        );

        final gridWidget = StreamBuilder<Map<DateTime, List<dynamic>>>(
          // We'll map EntryRecord type dynamically (avoid import cycles in this file)
          stream: repo
              .watchByDayRange(startLocal, endLocal, onlyShowInCalendar: true)
              .cast<Map<DateTime, List<dynamic>>>(),
          builder: (context, snapshot) {
            final byDay = snapshot.data ?? const <DateTime, List<dynamic>>{};
            final hasAny = byDay.values.any((l) => l.isNotEmpty);

            final gridView = GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.all(grid.padding),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: grid.columns,
                mainAxisSpacing: grid.mainAxisSpacing,
                crossAxisSpacing: grid.crossAxisSpacing,
                childAspectRatio: aspect,
              ),
              itemCount: daysToShow,
              itemBuilder: (context, i) {
                final date = firstCellUtc.add(Duration(days: i)).toLocal();
                final dayKey = DateTime(date.year, date.month, date.day);
                final items = byDay[dayKey] ?? const [];

                // Map entries to accent colors for dot rendering
                final entriesWithColor = <({EntryRecord entry, Color color})>[];
                for (final rec in items.cast<EntryRecord>()) {
                  final kindId = rec.widgetKind;
                  final kind = registry.byId(kindId);
                  if (kind != null) {
                    entriesWithColor.add((entry: rec, color: kind.accentColor));
                  } else if (kindId == 'product') {
                    entriesWithColor.add((entry: rec, color: Colors.purple));
                  }
                }

                // Cap visible dots at 4
                final maxDots = 4;
                final visible = entriesWithColor.take(maxDots).toList();
                final overflow = (entriesWithColor.length - maxDots).clamp(
                  0,
                  999,
                );

                return LayoutBuilder(
                  builder: (cellCtx, cellConstraints) {
                    final cellH = cellConstraints.maxHeight;
                    final cellW = cellConstraints.maxWidth;
                    // Guard: when cells are very small during animation, avoid laying out text/rows
                    const minContentH =
                        36.0; // safe minimum to render text + dots
                    final canRenderContent =
                        cellH >= minContentH && cellW >= minContentH;

                    return SizedBox(
                      height: 44,
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: GestureDetector(
                          onTap: () {
                            ref.read(selectedDayProvider.notifier).state =
                                DateTime(date.year, date.month, date.day);
                            final newAnchor = date.subtract(
                              Duration(days: date.weekday - 1),
                            );
                            ref.read(calendarAnchorProvider.notifier).state =
                                newAnchor;
                          },
                          // No decoration, margins, or padding — just raw content
                          child: canRenderContent
                              ? FittedBox(
                                  fit: BoxFit.scaleDown,
                                  // shrink if needed, never grow past 44
                                  alignment: Alignment.topLeft,
                                  // stick to top-left
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Day label with compact line height (no extra leading)
                                      Text(
                                        '${date.day}',
                                        maxLines: 1,
                                        overflow: TextOverflow.fade,
                                        softWrap: false,
                                        textHeightBehavior:
                                            const TextHeightBehavior(
                                              applyHeightToFirstAscent: false,
                                              applyHeightToLastDescent: false,
                                            ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                              height: 1.0,
                                              leadingDistribution:
                                                  TextLeadingDistribution.even,
                                            ),
                                      ),

                                      const SizedBox(height: 2),

                                      // tiny gap (will also scale if needed)
                                      if (visible.isNotEmpty)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            for (
                                              int i = 0;
                                              i < visible.length;
                                              i++
                                            ) ...[
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: visible[i].color,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              if (i != visible.length - 1)
                                                const SizedBox(width: 2),
                                            ],

                                            if (overflow > 0) ...[
                                              const SizedBox(width: 4),

                                              Text(
                                                '+$overflow',
                                                maxLines: 1,
                                                overflow: TextOverflow.clip,
                                                textHeightBehavior:
                                                    const TextHeightBehavior(
                                                      applyHeightToFirstAscent:
                                                          false,
                                                      applyHeightToLastDescent:
                                                          false,
                                                    ),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      height: 1.0,
                                                      leadingDistribution:
                                                          TextLeadingDistribution
                                                              .even,
                                                    ),
                                              ),
                                            ],
                                          ],
                                        ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    );
                  },
                );
              },
            );
            if (!hasAny) {
              return Stack(
                children: [
                  Center(
                    child: Text(
                      'No entries this week yet',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  gridView,
                ],
              );
            } else {
              return gridView;
            }
          },
        );

        return Column(
          children: [
            header,
            SizedBox(height: 44, child: gridWidget),
          ],
        );
      },
    );
  }
}

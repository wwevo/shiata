import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/entries_repository.dart';
import '../../domain/widgets/registry.dart';
import '../main_screen_providers.dart';
import '../ux_config.dart';

class WeeklyCalendar extends ConsumerWidget {
  const WeeklyCalendar({super.key, required this.grid, this.onDayTap});

  final CalendarGridConfig grid;
  final void Function(DateTime day)? onDayTap;

  void _changeRange(WidgetRef ref, DateTime current, int delta) {
    final next = current.add(Duration(days: 7 * delta));
    ref.read(headerCalendarAnchorProvider.notifier).state = next;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anchor = ref.watch(headerCalendarAnchorProvider);
    final registry = ref.watch(widgetRegistryProvider);
    const navigationExtent = 48.0;
    const horizontalPadding = 8.0;
    const verticalPadding = 6.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (grid.columns <= 0 || grid.rows <= 0) {
          return const SizedBox.shrink();
        }
        final gridWidth =
            constraints.maxWidth -
            horizontalPadding * 2 -
            navigationExtent * 2 -
            grid.padding * 2;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight - verticalPadding * 2
            : 68.0;
        final gridHeight = availableHeight - grid.padding * 2;
        if (gridWidth <= 0 || gridHeight <= grid.paintMinHeightPx) {
          return const SizedBox.shrink();
        }
        final totalSpacingW = grid.crossAxisSpacing * (grid.columns - 1);
        final totalSpacingH = grid.mainAxisSpacing * (grid.rows - 1);
        final cellWidth = (gridWidth - totalSpacingW) / grid.columns;
        final contentHeight = gridHeight - grid.padding * 2;
        final cellHeight = (contentHeight - totalSpacingH) / grid.rows;
        if (cellWidth <= grid.paintMinCellPx ||
            cellHeight <= grid.paintMinCellPx) {
          return const SizedBox.shrink();
        }

        final gridAsync = ref.watch(calendarEntriesProvider);
        final byDay =
            gridAsync.valueOrNull ?? const <DateTime, List<EntryRecord>>{};
        const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

        Widget buildDayCell(int index) {
          final date = DateTime(anchor.year, anchor.month, anchor.day + index);
          final dayKey = DateTime(date.year, date.month, date.day);
          final items = byDay[dayKey] ?? const <EntryRecord>[];

          final entriesWithColor = <({EntryRecord entry, Color color})>[];
          for (final rec in items) {
            final kindId = rec.widgetKind;
            final kind = registry.byId(kindId);
            if (kind != null) {
              entriesWithColor.add((entry: rec, color: kind.accentColor));
            } else if (kindId == 'product') {
              entriesWithColor.add((entry: rec, color: Colors.purple));
            }
          }

          const maxDots = 4;
          final visible = entriesWithColor.take(maxDots).toList();
          final overflow = (entriesWithColor.length - maxDots).clamp(0, 999);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final tappedDay = DateTime(date.year, date.month, date.day);
              if (onDayTap != null) {
                onDayTap!(tappedDay);
              } else {
                ref.read(selectedDayProvider.notifier).state = tappedDay;
                ref.read(calendarAnchorProvider.notifier).state = date.subtract(
                  Duration(days: date.weekday - 1),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${date.day}',
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      weekdays[date.weekday - 1],
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (visible.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int i = 0; i < visible.length; i++) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: visible[i].color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            if (i != visible.length - 1)
                              const SizedBox(width: 2),
                          ],
                          if (overflow > 0) ...[
                            const SizedBox(width: 3),
                            Text(
                              '+$overflow',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        }

        final gridContent = Padding(
          padding: EdgeInsets.all(grid.padding),
          child: Column(
            children: [
              for (int row = 0; row < grid.rows; row++) ...[
                if (row > 0) SizedBox(height: grid.mainAxisSpacing),
                Expanded(
                  child: Row(
                    children: [
                      for (int column = 0; column < grid.columns; column++) ...[
                        if (column > 0) SizedBox(width: grid.crossAxisSpacing),
                        Expanded(
                          child: buildDayCell(row * grid.columns + column),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous week',
                constraints: const BoxConstraints.tightFor(
                  width: navigationExtent,
                  height: navigationExtent,
                ),
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: () => _changeRange(ref, anchor, -1),
              ),
              Expanded(
                child: SizedBox(height: gridHeight, child: gridContent),
              ),
              IconButton(
                tooltip: 'Next week',
                constraints: const BoxConstraints.tightFor(
                  width: navigationExtent,
                  height: navigationExtent,
                ),
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: () => _changeRange(ref, anchor, 1),
              ),
            ],
          ),
        );
      },
    );
  }
}

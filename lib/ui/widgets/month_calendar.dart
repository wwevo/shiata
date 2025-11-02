import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main_screen_providers.dart';
import '../../data/providers.dart';
import '../../data/repo/entries_repository.dart';
import '../../domain/widgets/registry.dart';
// import '../editors/protein_editor.dart';
// import '../editors/fat_editor.dart';
// import '../editors/carbohydrate_editor.dart';
import '../editors/generic_nutrient_editor.dart';
import '../ux_config.dart';

class MonthCalendar extends ConsumerWidget {
  const MonthCalendar({super.key, required this.grid});
  final CalendarGridConfig grid;

  void _changeMonth(WidgetRef ref, DateTime current, int delta) {
    final next = DateTime(current.year, current.month + delta, 1);
    ref.read(visibleMonthProvider.notifier).state = next;
    // Keep a selected day always; if selection falls outside new month, pick a sensible default.
    final sel = ref.read(selectedDayProvider);
    if (sel == null || sel.year != next.year || sel.month != next.month) {
      final today = DateTime.now();
      if (today.year == next.year && today.month == next.month) {
        ref.read(selectedDayProvider.notifier).state = DateTime(today.year, today.month, today.day);
      } else {
        ref.read(selectedDayProvider.notifier).state = DateTime(next.year, next.month, 1);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch selected day so selection highlight updates immediately
    final selectedDay = ref.watch(selectedDayProvider);
    final visibleMonth = ref.watch(visibleMonthProvider);
    // Start of visible month in local time
    final firstOfMonthLocal = DateTime(visibleMonth.year, visibleMonth.month, 1);
    // Offset so that the first calendar cell is a Sunday
    final offsetToSunday = firstOfMonthLocal.weekday % 7; // Mon=1..Sun=7
    final firstCellLocal = firstOfMonthLocal.subtract(Duration(days: offsetToSunday));
    // Use UTC for day iteration to avoid DST-related duplicate/missing local dates
    final firstCellUtc = DateTime.utc(firstCellLocal.year, firstCellLocal.month, firstCellLocal.day);
    final daysToShow = grid.columns * grid.rows; // 42

    final repo = ref.watch(entriesRepositoryProvider);
    final registry = ref.watch(widgetRegistryProvider);

    if (repo == null) {
      return const SizedBox.shrink();
    }

    String monthLabel(DateTime m) {
      final monthNames = const [
        'January','February','March','April','May','June','July','August','September','October','November','December'
      ];
      return '${monthNames[m.month - 1]} ${m.year}';
    }

    // Build responsive grid with aspect ratio matching available space
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridWidth = constraints.maxWidth - grid.padding * 2;
        final gridHeight = constraints.maxHeight - grid.padding * 2 - 36; // reserve header height
        if (gridWidth <= 0 || gridHeight <= grid.paintMinHeightPx) {
          return const SizedBox.shrink();
        }
        final totalSpacingW = grid.crossAxisSpacing * (grid.columns - 1);
        final totalSpacingH = grid.mainAxisSpacing * (grid.rows - 1);
        final cellWidth = (gridWidth - totalSpacingW) / grid.columns;
        final cellHeight = (gridHeight - totalSpacingH) / grid.rows;
        if (cellWidth <= grid.paintMinCellPx || cellHeight <= grid.paintMinCellPx) {
          return const SizedBox.shrink();
        }
        final aspect = cellWidth / cellHeight;

        // Stream for entries within the visible calendar window (local dates)
        final startLocal = firstCellLocal;
        final endLocal = firstCellLocal.add(Duration(days: daysToShow));

        final header = Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeMonth(ref, visibleMonth, -1),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    monthLabel(visibleMonth),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeMonth(ref, visibleMonth, 1),
              ),
            ],
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
                final isCurrentMonth = date.month == visibleMonth.month && date.year == visibleMonth.year;
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
                final overflow = (entriesWithColor.length - maxDots).clamp(0, 999);

                return LayoutBuilder(
                  builder: (cellCtx, cellConstraints) {
                    final cellH = cellConstraints.maxHeight;
                    final cellW = cellConstraints.maxWidth;
                    // Guard: when cells are very small during animation, avoid laying out text/rows
                    const minContentH = 28.0; // safe minimum to render text + dots
                    final canRenderContent = cellH >= minContentH && cellW >= minContentH;

                    final selected = ref.read(selectedDayProvider);
                    final isSelected = selected != null &&
                        selected.year == date.year && selected.month == date.month && selected.day == date.day;
                    return GestureDetector(
                      onTap: () {
                        ref.read(selectedDayProvider.notifier).state = DateTime(date.year, date.month, date.day);
                        ref.read(visibleMonthProvider.notifier).state = DateTime(date.year, date.month, 1);
                      },
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: isCurrentMonth ? 0.4 : 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                              : null,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: canRenderContent
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${date.day}',
                                      maxLines: 1,
                                      overflow: TextOverflow.fade,
                                      softWrap: false,
                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                            color: isCurrentMonth
                                                ? Theme.of(context).colorScheme.onSurface
                                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                          ),
                                    ),
                                    const Spacer(),
                                    if (visible.isNotEmpty)
                                      Wrap(
                                        spacing: 2,
                                        runSpacing: 2,
                                        children: [
                                          for (final v in visible)
                                            GestureDetector(
                                              onTap: () {
                                                final e = v.entry;
                                                // Open editor directly for this entry
/*
                                                if (e.widgetKind == 'protein') {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(builder: (_) => ProteinEditorScreen(entryId: e.id)),
                                                  );
                                                } else if (e.widgetKind == 'fat') {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(builder: (_) => FatEditorScreen(entryId: e.id)),
                                                  );
                                                } else if (e.widgetKind == 'carbohydrate') {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(builder: (_) => CarbohydrateEditorScreen(entryId: e.id)),
                                                  );
                                                } else {
*/
                                                final k = registry.byId(e.widgetKind);
                                                if (k != null) {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(builder: (_) => GenericNutrientEditorScreen(kind: k, entryId: e.id)),
                                                  );
                                                }
//                                                }
                                              },
                                              child: Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(color: v.color, shape: BoxShape.circle),
                                              ),
                                            ),
                                          if (overflow > 0)
                                            GestureDetector(
                                              onTap: () {
                                                // Select day to open Day Details
                                                ref.read(selectedDayProvider.notifier).state = DateTime(date.year, date.month, date.day);
                                              },
                                              child: Text('+$overflow', style: Theme.of(context).textTheme.labelSmall),
                                            ),
                                        ],
                                      ),
                                  ],
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
                  gridView,
                  Center(
                    child: Text(
                      'No entries this month yet',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                    ),
                  ),
                ],
              );
            } else {
              return gridView;
            }
          },
        );

        return GestureDetector(
          onHorizontalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v < 0) {
              _changeMonth(ref, visibleMonth, 1); // swipe left → next month
            } else if (v > 0) {
              _changeMonth(ref, visibleMonth, -1); // swipe right → previous month
            }
          },
          child: Column(
            children: [
              header,
              Expanded(child: gridWidget),
            ],
          ),
        );
      },
    );
  }
}

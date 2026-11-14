import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/entries_repository.dart';
import '../../domain/widgets/registry.dart';
import '../main_screen_providers.dart';

/// Returns a list of accent colors per day for the current week (Mon–Sun).
/// Each inner list contains the accent color of each top-level entry for that day.
final circleHeaderDayDataProvider =
    StreamProvider.family<List<List<Color>>, DateTime>((ref, monday) {
  final repo = ref.watch(entriesRepositoryProvider);
  if (repo == null) return Stream.value(List.filled(7, <Color>[]));

  final registry = ref.watch(widgetRegistryProvider);
  final nextMonday = monday.add(const Duration(days: 7));
  return repo.watchByDayRange(monday, nextMonday, onlyShowInCalendar: false).map((byDay) {
    return List<List<Color>>.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      final key = DateTime(day.year, day.month, day.day);
      final records = byDay[key] ?? const <EntryRecord>[];
      final topLevel = records.where((e) => e.sourceEntryId == null).toList();
      // Cap at 6 segments to avoid overcrowding small circles
      final capped = topLevel.take(6).toList();
      return capped.map((rec) {
        final kind = registry.byId(rec.widgetKind);
        if (kind != null) return kind.accentColor;
        // Fallback colors for unknown kinds
        return rec.widgetKind == 'product' ? Colors.purple : Colors.grey;
      }).toList();
    });
  });
});

/// A row of 7 segmented circles representing Mon–Sun for the current week.
/// Each circle is divided into arcs proportional to the number of top-level
/// calendar entries on that day. The current day is highlighted with a ring.
class CircleWeekHeader extends ConsumerWidget {
  const CircleWeekHeader({
    super.key,
    required this.monday,
    this.onDayTap,
  });

  final DateTime monday;
  final void Function(DateTime day)? onDayTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorsAsync = ref.watch(circleHeaderDayDataProvider(monday));

    return colorsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (dayColors) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        // Weekday abbreviations
        const abbrevs = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              // Previous week button
              IconButton(
                tooltip: 'Previous week',
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: () {
                  ref.read(headerCalendarAnchorProvider.notifier).state =
                      monday.subtract(const Duration(days: 7));
                },
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(7, (i) {
                    final day = monday.add(Duration(days: i));
                    final dayKey = DateTime(day.year, day.month, day.day);
                    final isToday = dayKey.year == today.year &&
                        dayKey.month == today.month &&
                        dayKey.day == today.day;
                    return _CircleDay(
                      day: day,
                      entryColors: dayColors[i],
                      isCurrentDay: isToday,
                      weekdayAbbr: abbrevs[i],
                      theme: theme,
                      onDayTap: onDayTap,
                    );
                  }),
                ),
              ),
              // Next week button
              IconButton(
                tooltip: 'Next week',
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: () {
                  ref.read(headerCalendarAnchorProvider.notifier).state =
                      monday.add(const Duration(days: 7));
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CircleDay extends StatelessWidget {
  const _CircleDay({
    required this.day,
    required this.entryColors,
    required this.isCurrentDay,
    required this.weekdayAbbr,
    required this.theme,
    this.onDayTap,
  });

  final DateTime day;
  final List<Color> entryColors;
  final bool isCurrentDay;
  final String weekdayAbbr;
  final ThemeData theme;
  final void Function(DateTime day)? onDayTap;

  @override
  Widget build(BuildContext context) {
    final dayNumber = day.day;
    return GestureDetector(
      onTap: () {
        if (onDayTap != null) {
          onDayTap!(day);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CustomPaint(
              painter: _SegmentedCirclePainter(
                entryColors: entryColors,
                isCurrentDay: isCurrentDay,
                theme: theme,
              ),
              child: Center(
                child: Text(
                  '$dayNumber',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: isCurrentDay ? FontWeight.bold : FontWeight.normal,
                    color: isCurrentDay
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            weekdayAbbr,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedCirclePainter extends CustomPainter {
  _SegmentedCirclePainter({
    required this.entryColors,
    required this.isCurrentDay,
    required this.theme,
  });

  final List<Color> entryColors;
  final bool isCurrentDay;
  final ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Draw the outer ring for current day
    if (isCurrentDay) {
      final ringPaint = Paint()
        ..color = theme.colorScheme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(center, radius + 1, ringPaint);
    }

    if (entryColors.isEmpty) {
      // Draw a faint empty circle
      final emptyPaint = Paint()
        ..color = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius, emptyPaint);
      return;
    }

    // Draw segmented arcs — one arc per entry color
    final segmentCount = entryColors.length;
    final gapDegrees = 3.0; // small gap between segments
    final totalGap = gapDegrees * segmentCount;
    final segmentDegrees = (360.0 - totalGap) / segmentCount;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    double startAngle = -90.0; // Start from top
    for (int i = 0; i < segmentCount; i++) {
      paint.color = entryColors[i];
      final startRad = startAngle * 3.1415927 / 180.0;
      final sweepRad = segmentDegrees * 3.1415927 / 180.0;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startRad,
        sweepRad,
        false,
        paint,
      );
      startAngle += segmentDegrees + gapDegrees;
    }
  }

  @override
  bool shouldRepaint(_SegmentedCirclePainter oldDelegate) {
    return entryColors != oldDelegate.entryColors ||
        isCurrentDay != oldDelegate.isCurrentDay;
  }
}

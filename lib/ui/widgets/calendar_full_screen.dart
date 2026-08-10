import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ux_config.dart';
import 'day_details_panel.dart';
import 'weekly_calendar.dart';

/// Full-screen calendar view with week-line and day details below.
class CalendarFullScreen extends ConsumerWidget {
  const CalendarFullScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(uxConfigProvider);
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Calendar grid (fixed height)
          SizedBox(
            height: 120,
            child: WeeklyCalendar(grid: config.calendarGrid),
          ),
          const Divider(height: 1),
          // Content area (day details)
          const Expanded(child: DayDetailsPanel()),
        ],
      ),
    );
  }
}

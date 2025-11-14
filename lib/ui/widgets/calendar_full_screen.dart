import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'day_details_panel.dart';
import 'month_calendar.dart';
import '../ux_config.dart';

/// Full-screen calendar view with month grid and day details.
/// No sliding mechanism - always visible in calendar mode.
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
            height: 350,
            child: MonthCalendar(grid: config.calendarGrid),
          ),
          const Divider(height: 1),
          // Day details panel (expands to fill remaining space)
          const Expanded(child: DayDetailsPanel()),
        ],
      ),
    );
  }
}

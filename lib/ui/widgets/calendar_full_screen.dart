import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'day_details_panel.dart';
import 'month_calendar.dart';
import 'search_results.dart';
import '../main_screen_providers.dart';
import '../ux_config.dart';

/// Full-screen calendar view with month grid and content below.
/// Shows DayDetailsPanel normally, or SearchResults when searching.
class CalendarFullScreen extends ConsumerWidget {
  const CalendarFullScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(uxConfigProvider);
    final theme = Theme.of(context);
    final searchQuery = ref.watch(searchQueryProvider);
    final scrollController = ScrollController();

    // Show search results if there's a search query, otherwise show day details
    final content = searchQuery.trim().isNotEmpty
        ? SearchResults(controller: scrollController)
        : const DayDetailsPanel();

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
          // Content area (search results or day details)
          Expanded(child: content),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'main_screen_providers.dart';
import 'widgets/calendar_full_screen.dart';
import 'widgets/weekly_overview_panel.dart';

/// Main screen with two view modes:
/// - Overview: Weekly summary with pie chart and entry list
/// - Calendar: Full-screen calendar with day details
class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(viewModeProvider);

    return viewMode == ViewMode.overview
        ? const WeeklyOverviewPanel()
        : const CalendarFullScreen();
  }
}

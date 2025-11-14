import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'kinds/kinds_page.dart';
import 'main_screen_providers.dart';
import 'products/products_page.dart';
import 'recipes/recipes_page.dart';
import 'widgets/calendar_full_screen.dart';
import 'widgets/weekly_overview_panel.dart';

/// Main screen with section-based navigation:
/// - Calendar section (with overview/calendar toggle)
/// - Products section
/// - Kinds section
/// - Recipes section
class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(currentSectionProvider);
    final viewMode = ref.watch(viewModeProvider);

    switch (section) {
      case AppSection.calendar:
        // Within calendar section, use viewMode to switch between overview and calendar
        return viewMode == ViewMode.overview
            ? const WeeklyOverviewPanel()
            : const CalendarFullScreen();
      case AppSection.products:
        return const ProductTemplatesPage();
      case AppSection.kinds:
        return const KindsPage();
      case AppSection.recipes:
        return const RecipesPage();
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pages/database_page.dart';
import 'pages/kinds_page.dart';
import 'main_screen_providers.dart';
import 'pages/products_page.dart';
import 'pages/recipes_page.dart';
import 'pages/active_week_page.dart';

/// Main screen with section-based navigation:
/// - Overview section (weekly summary with pie chart)
/// - Products section
/// - Kinds section
/// - Recipes section
/// - All Entries section
/// - Database section
class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(currentSectionProvider);

    switch (section) {
      case AppSection.products:
        return const ProductTemplatesPage();
      case AppSection.kinds:
        return const KindsPage();
      case AppSection.recipes:
        return const RecipesPage();
      case AppSection.database:
        return const DatabasePage();
      default:
        // Fallback to overview to satisfy exhaustive checking in some analyzers
        return const ActiveWeekPage();
    }
  }
}
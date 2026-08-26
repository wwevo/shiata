import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'main_screen_providers.dart';
import 'pages/active_week_page.dart';
import 'pages/collections_page.dart';
import 'pages/cooking_aid_page.dart';
import 'pages/database_admin_page.dart';
import 'pages/database_page.dart';
import 'pages/kinds_page.dart';
import 'pages/products_page.dart';
import 'pages/recipes_page.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(currentSectionProvider);

    switch (section) {
      case AppSection.cookingaids:
        return const CookingAidPage();
      case AppSection.products:
        return const ProductTemplatesPage();
      case AppSection.kinds:
        return const KindsPage();
      case AppSection.recipes:
        return const RecipesPage();
      case AppSection.database:
        return const DatabasePage();
      case AppSection.databaseAdmin:
        return const DatabaseAdminPage();
      case AppSection.collections:
        return const CollectionsPage();
      default:
        return const ActiveWeekPage();
    }
  }
}
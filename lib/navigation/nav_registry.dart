import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/main_screen_providers.dart';
import '../ui/pages/active_week_page.dart';
import '../ui/pages/collections_page.dart';
import '../ui/pages/cooking_aid_page.dart';
import '../ui/pages/database_admin_page.dart';
import '../ui/pages/database_page.dart';
import '../ui/pages/kinds_page.dart';
import '../ui/pages/products_page.dart';
import '../ui/pages/recipes_page.dart';
import 'nav_models.dart';

class NavRegistry {
  final List<NavItem> items;

  const NavRegistry(this.items);

  /// Recursively find a page item by its string ID.
  NavPageItem? findPage(String id) {
    for (final item in items) {
      if (item is NavPageItem && item.id == id) return item;
      if (item is NavGroupItem) {
        for (final child in item.children) {
          if (child is NavPageItem && child.id == id) return child;
        }
      }
    }
    return null;
  }

  /// Find any NavItem by its string ID (top-level or child).
  NavItem? findItem(String id) {
    for (final item in items) {
      if (item.id == id) return item;
      if (item is NavGroupItem) {
        for (final child in item.children) {
          if (child.id == id) return child;
        }
      }
    }
    return null;
  }

  /// Find which top-level index corresponds to the currently active page ID.
  int findTopLevelIndex(String currentId) {
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.id == currentId) return i;
      if (item is NavGroupItem) {
        if (item.children.any((c) => c.id == currentId)) return i;
      }
    }
    return 0;
  }
}

final navRegistryProvider = Provider<NavRegistry>((ref) {
  return NavRegistry([
    NavGroupItem(
      id: 'tracking_group',
      label: 'Tracking',
      icon: Icons.format_list_bulleted_outlined,
      selectedIcon: Icons.format_list_bulleted,
      children: [
        NavPageItem(
          id: 'active_week',
          label: 'Active Week',
          icon: Icons.restaurant_menu_outlined,
          selectionCategory: SelectionCategory.entries,
          pageBuilder: (_, _) => const ActiveWeekPage(),
        ),
        NavPageItem(
          id: 'cookingaids',
          label: 'Cooking Aid',
          icon: Icons.shopping_basket_outlined,
          selectionCategory: SelectionCategory.cookingaids,
          pageBuilder: (_, _) => const CookingAidPage(),
        ),
      ],
    ),
    NavGroupItem(
      id: 'food_group',
      label: 'Food',
      icon: Icons.fastfood_outlined,
      selectedIcon: Icons.fastfood,
      children: [
        NavPageItem(
          id: 'recipes',
          label: 'Recipes',
          icon: Icons.restaurant_menu_outlined,
          selectionCategory: SelectionCategory.recipes,
          pageBuilder: (_, _) => const RecipesPage(),
        ),
        NavPageItem(
          id: 'products',
          label: 'Products',
          icon: Icons.shopping_basket_outlined,
          selectionCategory: SelectionCategory.products,
          pageBuilder: (_, _) => const ProductTemplatesPage(),
        ),
        NavPageItem(
          id: 'kinds',
          label: 'Kinds',
          icon: Icons.category_outlined,
          selectionCategory: SelectionCategory.kinds,
          pageBuilder: (_, _) => const KindsPage(),
        ),
        NavPageItem(
          id: 'collections',
          label: 'Collections',
          icon: Icons.collections_outlined,
          selectionCategory: SelectionCategory.collections,
          pageBuilder: (_, _) => const CollectionsPage(),
        ),
      ],
    ),
    NavGroupItem(
      id: 'settings',
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      children: [
        NavPageItem(
          id: 'database',
          label: 'Settings',
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
          categoryResolver: (ref) => ref.watch(databaseCategoryProvider),
          pageBuilder: (_, _) => const DatabasePage(),
        ),
        NavPageItem(
          id: 'database_admin',
          label: 'Admin Settings',
          icon: Icons.settings_ethernet_outlined,
          selectedIcon: Icons.settings_ethernet,
          pageBuilder: (_, _) => const DatabaseAdminPage(),
        )
      ]
    ),
  ]);
});

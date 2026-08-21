import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../data/repo/recipes_repository.dart';
import './widgets/entry_list_item_factory.dart';

// Visible calendar anchor (e.g. start of week). Used by calendar navigation.
final calendarAnchorProvider = StateProvider<DateTime>((_) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  // Default to start of current week (Monday)
  return today.subtract(Duration(days: today.weekday - 1));
});

// Selected day (local date at midnight) for Day Details panel
final selectedDayProvider = StateProvider<DateTime?>((ref) {
  final now = DateTime.now();
  // Initialize selected day to today. Do not mutate other providers here to
  // avoid Riverpod initialization side-effects.
  return DateTime(now.year, now.month, now.day);
});

// App section navigation (main sections of the app)
enum AppSection {
  activeWeek,
  products,
  kinds,
  recipes,
  database,
  databaseAdmin
}

final currentSectionProvider = StateProvider<AppSection>(
      (_) => AppSection.activeWeek,
);

// Expanded product parents in Day Details (by parent entry id)
final expandedProductsProvider = StateProvider<Set<String>>((_) => <String>{});
// Global expanded entries (for recursive list items across all pages)
final expandedEntriesProvider = StateProvider<Set<String>>((_) => <String>{});

// All Entries page filters
enum EntrySortMode { newest, oldest }

final entrySortModeProvider = StateProvider<EntrySortMode>(
      (_) => EntrySortMode.newest,
);

// Entry type filter: empty = show all, non-empty = show only selected types
// Valid types: 'kind' (direct nutrient entries), 'product', 'recipe'
final entryTypeFilterProvider = StateProvider<Set<String>>((_) => <String>{});

// Bulk selection categories (correspond to main list pages/tabs)
enum SelectionCategory { entries, kinds, products, recipes }

// Active database tab (0=entries, 1=kinds, 2=products, 3=recipes)
final databaseTabProvider = StateProvider<int>((_) => 0);

// Current active category based on section and database tab
final activeCategoryProvider = Provider<SelectionCategory>((ref) {
  final section = ref.watch(currentSectionProvider);
  switch (section) {
    case AppSection.activeWeek:
      return SelectionCategory.entries;
    case AppSection.products:
      return SelectionCategory.products;
    case AppSection.kinds:
      return SelectionCategory.kinds;
    case AppSection.recipes:
      return SelectionCategory.recipes;
    case AppSection.database:
      final tabIndex = ref.watch(databaseTabProvider);
      switch (tabIndex) {
        case 0:
          return SelectionCategory.entries;
        case 1:
          return SelectionCategory.kinds;
        case 2:
          return SelectionCategory.products;
        case 3:
          return SelectionCategory.recipes;
        default:
          return SelectionCategory.entries;
      }
    case AppSection.databaseAdmin:
      // TODO: Handle this case.
      throw UnimplementedError();
  }
});

// Bulk selection state (holds Map of entry ID -> category)
final bulkSelectionProvider =
    StateProvider<Map<String, SelectionCategory>>((_) => {});

// Whether selection mode is active
final selectionModeProvider = StateProvider<bool>((_) => false);

/// Combined hierarchy for management pages (Kinds, Products, Recipes)
final managementHierarchyProvider = Provider<Map<String, List<dynamic>>>((ref) {
  final kinds = ref.watch(kindsListProvider).value ?? [];
  final products = ref.watch(allProductsListProvider).value ?? [];
  final productComponents = ref.watch(allProductComponentsProvider).value ?? [];
  final recipeComponents = ref.watch(allRecipeComponentsProvider).value ?? [];

  final Map<String, List<dynamic>> map = {};

  final kindMap = {for (final k in kinds) k.id: k};
  final productMap = {for (final p in products) p.id: p};

  // Map product components
  for (final pc in productComponents) {
    final kind = kindMap[pc.kindId];
    if (kind != null) {
      map.putIfAbsent(pc.productId, () => []).add(
            ComponentItem(
              definition: kind,
              amount: pc.amountPerGram,
              unit: '${kind.unit}/g',
            ),
          );
    }
  }

  // Map recipe components
  for (final rc in recipeComponents) {
    if (rc.type == RecipeComponentType.product) {
      final product = productMap[rc.compId];
      if (product != null) {
        map.putIfAbsent(rc.recipeId, () => []).add(
              ComponentItem(
                definition: product,
                amount: rc.grams?.toDouble(),
                unit: 'g',
              ),
            );
      }
    } else {
      final kind = kindMap[rc.compId];
      if (kind != null) {
        map.putIfAbsent(rc.recipeId, () => []).add(
              ComponentItem(
                definition: kind,
                amount: rc.amount,
                unit: kind.unit,
              ),
            );
      }
    }
  }

  return map;
});
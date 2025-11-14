import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/kinds_repository.dart';
import '../../data/repo/products_repository.dart';
import '../../data/repo/recipes_repository.dart';
import 'create_action.dart';
import 'kinds/db_backed_kind.dart';
import 'products/db_backed_product.dart';
import 'recipes/db_backed_recipe.dart';
import 'widget_kind.dart';

/// Holds all registered widget kinds and provides simple helpers.
class WidgetRegistry {
  WidgetRegistry(this._kinds);

  final Map<String, WidgetKind> _kinds;

  /// All registered widget kinds (Kinds, Products, Recipes)
  List<WidgetKind> get all => _kinds.values.toList(growable: false);

  /// Only "real" Kinds (nutrients/macros) - excludes Products and Recipes
  List<WidgetKind> get kinds => _kinds.values
      .where((k) => !k.id.startsWith('product:') && !k.id.startsWith('recipe:'))
      .toList(growable: false);

  /// Only Products
  List<WidgetKind> get products => _kinds.values
      .where((k) => k.id.startsWith('product:'))
      .toList(growable: false);

  /// Only Recipes
  List<WidgetKind> get recipes => _kinds.values
      .where((k) => k.id.startsWith('recipe:'))
      .toList(growable: false);

  WidgetKind? byId(String id) => _kinds[id];

  /// Aggregate all actions for a target date from all kinds.
  List<({WidgetKind kind, CreateAction action})> actionsForDate(
      BuildContext context,
      DateTime targetDate,
      ) {
    final items = <({WidgetKind kind, CreateAction action})>[];
    for (final kind in _kinds.values) {
      final acts = kind.createActions(context, targetDate);
      for (final a in acts) {
        items.add((kind: kind, action: a));
      }
    }
    // Order by priority desc, then label asc
    items.sort((a, b) {
      final p = b.action.priority.compareTo(a.action.priority);
      if (p != 0) return p;
      return a.action.label.compareTo(b.action.label);
    });
    return items;
  }
}

final widgetRegistryProvider = Provider<WidgetRegistry>((ref) {
  // Watch all three types
  final kindsValue = ref.watch(kindsListProvider);
  final productsValue = ref.watch(productsListProvider);
  final recipesValue = ref.watch(recipesListProvider);

  IconData resolveIcon(String? name, IconData fallback) {
    switch (name) {
      case 'fitness_center':
        return Icons.fitness_center;
      case 'opacity':
        return Icons.opacity;
      case 'rice_bowl':
        return Icons.rice_bowl;
      case 'battery_charging_full':
        return Icons.battery_charging_full;
      case 'blur_on':
        return Icons.blur_on;
      case 'bolt':
        return Icons.bolt;
      case 'circle':
        return Icons.circle;
      case 'hexagon':
        return Icons.hexagon;
      case 'science':
        return Icons.science;
      case 'visibility':
        return Icons.visibility;
      case 'medical_information':
        return Icons.medical_information;
      case 'local_florist':
        return Icons.local_florist;
      case 'wb_sunny':
        return Icons.wb_sunny;
      case 'eco':
        return Icons.eco;
      case 'grass':
        return Icons.grass;
      case 'shopping_basket':
        return Icons.shopping_basket;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'local_grocery_store':
        return Icons.local_grocery_store;
      case 'restaurant_menu':
        return Icons.restaurant_menu;
      case 'restaurant':
        return Icons.restaurant;
      case 'dinner_dining':
        return Icons.dinner_dining;
      default:
        return fallback;
    }
  }

  // Extract lists from AsyncValue
  final kinds = kindsValue.maybeWhen(
    data: (list) => list,
    orElse: () => const <KindDef>[],
  );

  final products = productsValue.maybeWhen(
    data: (list) => list,
    orElse: () => const <ProductDef>[],
  );

  final recipes = recipesValue.maybeWhen(
    data: (list) => list,
    orElse: () => const <RecipeDef>[],
  );

  final map = <String, WidgetKind>{};

  // Add Kinds (with original IDs)
  for (final k in kinds) {
    map[k.id] = DbBackedKind(k, iconResolver: resolveIcon);
  }

  // Add Products (with 'product:' prefix to avoid ID collisions)
  for (final p in products) {
    final adapter = DbBackedProduct(p, iconResolver: resolveIcon);
    map[adapter.id] = adapter; // Uses 'product:${p.id}'
  }

  // Add Recipes (with 'recipe:' prefix to avoid ID collisions)
  for (final r in recipes) {
    final adapter = DbBackedRecipe(r, iconResolver: resolveIcon);
    map[adapter.id] = adapter; // Uses 'recipe:${r.id}'
  }

  return WidgetRegistry(map);
});

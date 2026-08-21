import 'dart:convert';

import 'entries_repository.dart';
import 'kinds_repository.dart';
import 'products_repository.dart';
import 'recipes_repository.dart';
import '../../ui/main_screen_providers.dart';

class SelectionChangeResult {
  final Map<String, SelectionCategory> newSelection;
  final int includedChildCount;
  final List<String> deselectedParentNames;

  const SelectionChangeResult({
    required this.newSelection,
    this.includedChildCount = 0,
    this.deselectedParentNames = const [],
  });
}

class DatabaseSelectionService {
  /// Computes all descendants (child nodes all the way down) for a given entry.
  /// Returns a map of entry ID -> SelectionCategory.
  static Map<String, SelectionCategory> getDescendants({
    required String entryId,
    required SelectionCategory category,
    required List<KindDef> kinds,
    required List<ProductDef> products,
    required List<RecipeDef> recipes,
    required List<RecipeComponentDef> recipeComponents,
    required List<ProductComponent> productComponents,
    required List<EntryRecord> allEntries,
  }) {
    final result = <String, SelectionCategory>{};

    switch (category) {
      case SelectionCategory.recipes:
        final rComps =
            recipeComponents.where((rc) => rc.recipeId == entryId).toList();
        for (final rc in rComps) {
          if (rc.type == RecipeComponentType.product) {
            result[rc.compId] = SelectionCategory.products;
            // Also include product components (kinds)
            final pComps = productComponents
                .where((pc) => pc.productId == rc.compId)
                .toList();
            for (final pc in pComps) {
              result[pc.kindId] = SelectionCategory.kinds;
            }
          } else if (rc.type == RecipeComponentType.kind) {
            result[rc.compId] = SelectionCategory.kinds;
          }
        }
        break;

      case SelectionCategory.products:
        final pComps = productComponents
            .where((pc) => pc.productId == entryId)
            .toList();
        for (final pc in pComps) {
          result[pc.kindId] = SelectionCategory.kinds;
        }
        break;

      case SelectionCategory.kinds:
        // Kinds are leaf template nodes
        break;

      case SelectionCategory.entries:
        void collectChildEntries(String parentId) {
          for (final entry in allEntries) {
            if (entry.sourceEntryId == parentId && entry.id != parentId) {
              result[entry.id] = SelectionCategory.entries;
              collectChildEntries(entry.id);
            }
          }
        }

        collectChildEntries(entryId);
        break;
    }

    return result;
  }

  /// Computes all ancestor item IDs that depend on this entry (directly or transitively).
  /// Returns a map of ancestor ID -> SelectionCategory.
  static Map<String, SelectionCategory> getAncestors({
    required String entryId,
    required SelectionCategory category,
    required List<KindDef> kinds,
    required List<ProductDef> products,
    required List<RecipeDef> recipes,
    required List<RecipeComponentDef> recipeComponents,
    required List<ProductComponent> productComponents,
    required List<EntryRecord> allEntries,
  }) {
    final result = <String, SelectionCategory>{};

    switch (category) {
      case SelectionCategory.kinds:
        // Products that use this kind
        final directProductIds = productComponents
            .where((pc) => pc.kindId == entryId)
            .map((pc) => pc.productId)
            .toSet();
        for (final pId in directProductIds) {
          result[pId] = SelectionCategory.products;
        }

        // Recipes that use this kind directly
        final directRecipeIds = recipeComponents
            .where(
              (rc) =>
                  rc.type == RecipeComponentType.kind && rc.compId == entryId,
            )
            .map((rc) => rc.recipeId)
            .toSet();

        // Recipes that use products containing this kind
        final indirectRecipeIds = recipeComponents
            .where(
              (rc) =>
                  rc.type == RecipeComponentType.product &&
                  directProductIds.contains(rc.compId),
            )
            .map((rc) => rc.recipeId)
            .toSet();

        for (final rId in directRecipeIds.union(indirectRecipeIds)) {
          result[rId] = SelectionCategory.recipes;
        }
        break;

      case SelectionCategory.products:
        // Recipes that use this product
        final recipeIds = recipeComponents
            .where(
              (rc) =>
                  rc.type == RecipeComponentType.product &&
                  rc.compId == entryId,
            )
            .map((rc) => rc.recipeId)
            .toSet();
        for (final rId in recipeIds) {
          result[rId] = SelectionCategory.recipes;
        }
        break;

      case SelectionCategory.recipes:
        // Recipes are top-level templates
        break;

      case SelectionCategory.entries:
        String? currentParentId;
        for (final entry in allEntries) {
          if (entry.id == entryId) {
            currentParentId = entry.sourceEntryId;
            break;
          }
        }

        while (currentParentId != null &&
            currentParentId.isNotEmpty &&
            !result.containsKey(currentParentId)) {
          result[currentParentId] = SelectionCategory.entries;
          String? nextParentId;
          for (final entry in allEntries) {
            if (entry.id == currentParentId) {
              nextParentId = entry.sourceEntryId;
              break;
            }
          }
          currentParentId = nextParentId;
        }
        break;
    }

    return result;
  }

  /// Gets display names for the given item IDs across all categories.
  static List<String> getDisplayNames({
    required List<String> itemIds,
    required List<KindDef> kinds,
    required List<ProductDef> products,
    required List<RecipeDef> recipes,
    required List<EntryRecord> allEntries,
  }) {
    final names = <String>[];
    final kindMap = {for (final k in kinds) k.id: k.name};
    final productMap = {for (final p in products) p.id: p.name};
    final recipeMap = {for (final r in recipes) r.id: r.name};
    final entryMap = {for (final e in allEntries) e.id: e};

    for (final id in itemIds) {
      if (recipeMap.containsKey(id)) {
        names.add(recipeMap[id]!);
      } else if (productMap.containsKey(id)) {
        names.add(productMap[id]!);
      } else if (kindMap.containsKey(id)) {
        names.add(kindMap[id]!);
      } else if (entryMap.containsKey(id)) {
        final entry = entryMap[id]!;
        String? name;
        try {
          final payload = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
          name = payload['name'] as String?;
        } catch (_) {}
        names.add(name ?? entry.widgetKind);
      }
    }

    return names;
  }

  /// Handles selection or deselection of an item.
  /// Returns a [SelectionChangeResult] with the updated selection map,
  /// the number of child nodes included (for selection),
  /// and the names of parent items that were deselected (for deselection).
  static SelectionChangeResult handleSelectionChange({
    required String entryId,
    required SelectionCategory category,
    required bool selected,
    required Map<String, SelectionCategory> currentSelection,
    required List<KindDef> kinds,
    required List<ProductDef> products,
    required List<RecipeDef> recipes,
    required List<RecipeComponentDef> recipeComponents,
    required List<ProductComponent> productComponents,
    required List<EntryRecord> allEntries,
  }) {
    if (selected) {
      final descendants = getDescendants(
        entryId: entryId,
        category: category,
        kinds: kinds,
        products: products,
        recipes: recipes,
        recipeComponents: recipeComponents,
        productComponents: productComponents,
        allEntries: allEntries,
      );

      final newlyIncludedChildCount = descendants.keys
          .where((id) => !currentSelection.containsKey(id))
          .length;

      final newSelection = Map<String, SelectionCategory>.from(currentSelection);
      newSelection[entryId] = category;
      for (final e in descendants.entries) {
        newSelection[e.key] = e.value;
      }

      return SelectionChangeResult(
        newSelection: newSelection,
        includedChildCount: newlyIncludedChildCount,
      );
    } else {
      final ancestors = getAncestors(
        entryId: entryId,
        category: category,
        kinds: kinds,
        products: products,
        recipes: recipes,
        recipeComponents: recipeComponents,
        productComponents: productComponents,
        allEntries: allEntries,
      );

      final deselectedAncestors =
          ancestors.keys.where((id) => currentSelection.containsKey(id)).toList();

      final newSelection = Map<String, SelectionCategory>.from(currentSelection);
      newSelection.remove(entryId);
      for (final id in deselectedAncestors) {
        newSelection.remove(id);
      }

      final deselectedNames = getDisplayNames(
        itemIds: deselectedAncestors,
        kinds: kinds,
        products: products,
        recipes: recipes,
        allEntries: allEntries,
      );

      return SelectionChangeResult(
        newSelection: newSelection,
        deselectedParentNames: deselectedNames,
      );
    }
  }
}

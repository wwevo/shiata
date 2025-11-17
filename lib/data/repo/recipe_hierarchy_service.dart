import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/widgets/registry.dart';
import '../providers.dart';
import 'entries_repository.dart';
import 'nutrient_summary.dart';
import 'product_hierarchy_service.dart';
import 'recipe_service.dart';
import 'recipes_repository.dart';

/// Hierarchy information for a recipe instance.
class RecipeInstanceHierarchy {
  RecipeInstanceHierarchy({
    required this.parent,
    required this.productChildren,
    required this.kindChildren,
    required this.isStatic,
  });

  final EntryRecord parent;
  final List<ProductInstanceHierarchy> productChildren;
  final List<EntryRecord> kindChildren;
  final bool isStatic;
}

/// Service for managing recipe instance hierarchies and nutrient aggregation.
/// Handles recipe-level operations with RECURSIVE aggregation through products.
class RecipeHierarchyService {
  RecipeHierarchyService({
    required this.entries,
    required this.recipes,
    required this.recipeService,
    required this.productHierarchyService,
    required this.registry,
  });

  final EntriesRepository entries;
  final RecipesRepository recipes;
  final RecipeService recipeService;
  final ProductHierarchyService? productHierarchyService;
  final WidgetRegistry registry;

  /// Get recipe instance with all children (products + kinds).
  Future<RecipeInstanceHierarchy?> getRecipeInstance(String entryId) async {
    final parent = await entries.getById(entryId);
    if (parent == null || parent.widgetKind != 'recipe') {
      return null;
    }

    final children = await entries.listChildrenOfParent(entryId);
    final productChildren = <ProductInstanceHierarchy>[];
    final kindChildren = <EntryRecord>[];

    for (final child in children) {
      if (child.widgetKind == 'product') {
        final productHierarchy = await productHierarchyService?.getProductInstance(child.id);
        if (productHierarchy != null) {
          productChildren.add(productHierarchy);
        }
      } else {
        kindChildren.add(child);
      }
    }

    return RecipeInstanceHierarchy(
      parent: parent,
      productChildren: productChildren,
      kindChildren: kindChildren,
      isStatic: parent.isStatic,
    );
  }

  /// Aggregate nutrients RECURSIVELY (includes product children).
  /// Traverses: Recipe → Products → Nutrients (all levels).
  Future<NutrientSummary> aggregateNutrients(String recipeEntryId) async {
    final hierarchy = await getRecipeInstance(recipeEntryId);
    if (hierarchy == null) {
      return NutrientSummary.empty();
    }

    double totalProductGrams = 0.0;
    final nutrientsByKind = <String, double>{};
    final normalizedNutrients = <String, double>{};

    // Recursive helper
    void aggregateFromEntries(List<EntryRecord> entries) {
      for (final entry in entries) {
        final payload = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
        final amount = (payload['amount'] as num?)?.toDouble() ?? 0.0;

        // Sum original amounts
        nutrientsByKind[entry.widgetKind] = (nutrientsByKind[entry.widgetKind] ?? 0.0) + amount;

        // Normalize for comparison
        final kind = registry.byId(entry.widgetKind);
        final unit = kind?.unit ?? '';
        final normalized = NutrientSummary.normalizeToGrams(amount, unit);
        normalizedNutrients[entry.widgetKind] = (normalizedNutrients[entry.widgetKind] ?? 0.0) + normalized;
      }
    }

    // 1. Aggregate direct kind children (top-level nutrients)
    aggregateFromEntries(hierarchy.kindChildren);

    // 2. Aggregate from product children (RECURSIVE)
    for (final productHierarchy in hierarchy.productChildren) {
      // Add product weight
      totalProductGrams += productHierarchy.parent.productGrams?.toDouble() ?? 0.0;

      // Aggregate nutrients from product's children (grandchildren of recipe)
      aggregateFromEntries(productHierarchy.nutrientChildren);
    }

    return NutrientSummary(
      totalProductGrams: totalProductGrams,
      nutrientsByKind: nutrientsByKind,
      normalizedNutrients: normalizedNutrients,
    );
  }

  /// Reset static instance to template values.
  /// Deletes old children and recreates from template, marking as non-static.
  Future<void> resetToTemplate(String recipeEntryId) async {
    final entry = await entries.getById(recipeEntryId);
    if (entry == null || entry.widgetKind != 'recipe') {
      throw Exception('Entry is not a recipe instance');
    }
    if (!entry.isStatic) {
      throw Exception('Entry is not static - already dynamic');
    }
    if (entry.recipeId == null) {
      throw Exception('Entry has no recipe template link');
    }

    // Delete old children
    await entries.deleteChildrenOfParent(recipeEntryId);

    // Recreate from template
    final targetAt = DateTime.fromMillisecondsSinceEpoch(entry.targetAt, isUtc: true).toLocal();
    final comps = await recipes.getComponents(entry.recipeId!);

    // Recreate children using recipe service logic
    // TODO: This duplicates logic from RecipeService.createRecipeEntry
    // Consider refactoring to share child creation logic
    for (final c in comps) {
      if (c.type == RecipeComponentType.kind) {
        final amount = c.amount ?? 0.0;
        await entries.create(
          widgetKind: c.compId,
          targetAtLocal: targetAt,
          payload: {'amount': amount},
          showInCalendar: false,
          schemaVersion: 1,
          sourceEntryId: recipeEntryId,
          sourceWidgetKind: 'recipe',
        );
      } else {
        // Product component - delegate to ProductService
        final grams = c.grams ?? 0;
        if (grams > 0) {
          final productService = recipeService.productService;
          if (productService != null) {
            final productParentId = await productService.createProductEntry(
              productId: c.compId,
              productGrams: grams,
              targetAtLocal: targetAt,
              isStatic: false, // Mark as dynamic after reset
            );
            if (productParentId != null) {
              await entries.update(productParentId, {
                'source_entry_id': recipeEntryId,
                'source_widget_kind': 'recipe',
              });
            }
          }
        }
      }
    }

    // Mark recipe parent as non-static
    await entries.update(recipeEntryId, {'is_static': 0});
  }

  /// Propagate template changes to non-static instances.
  /// When a recipe template is updated, this recalculates all non-static instances.
  /// Returns the number of instances that were updated.
  Future<int> propagateTemplateChange(String recipeId) async {
    // Get all instances of this recipe
    final instances = await entries.listParentsByRecipeId(recipeId);

    int updatedCount = 0;
    for (final instance in instances) {
      if (!instance.isStatic) {
        // Reset and recreate from template
        await entries.deleteChildrenOfParent(instance.id);

        final targetAt = DateTime.fromMillisecondsSinceEpoch(instance.targetAt, isUtc: true).toLocal();
        final comps = await recipes.getComponents(recipeId);

        for (final c in comps) {
          if (c.type == RecipeComponentType.kind) {
            final amount = c.amount ?? 0.0;
            await entries.create(
              widgetKind: c.compId,
              targetAtLocal: targetAt,
              payload: {'amount': amount},
              showInCalendar: false,
              schemaVersion: 1,
              sourceEntryId: instance.id,
              sourceWidgetKind: 'recipe',
            );
          } else {
            final grams = c.grams ?? 0;
            if (grams > 0) {
              final productService = recipeService.productService;
              if (productService != null) {
                final productParentId = await productService.createProductEntry(
                  productId: c.compId,
                  productGrams: grams,
                  targetAtLocal: targetAt,
                  isStatic: false,
                );
                if (productParentId != null) {
                  await entries.update(productParentId, {
                    'source_entry_id': instance.id,
                    'source_widget_kind': 'recipe',
                  });
                }
              }
            }
          }
        }

        updatedCount++;
      }
    }

    return updatedCount;
  }
}

final recipeHierarchyServiceProvider = Provider<RecipeHierarchyService?>((ref) {
  final e = ref.watch(entriesRepositoryProvider);
  final r = ref.watch(recipesRepositoryProvider);
  final rs = ref.watch(recipeServiceProvider);
  final phs = ref.watch(productHierarchyServiceProvider);
  final registry = ref.watch(widgetRegistryProvider);
  if (e == null || r == null || rs == null) return null;
  return RecipeHierarchyService(
    entries: e,
    recipes: r,
    recipeService: rs,
    productHierarchyService: phs,
    registry: registry,
  );
});

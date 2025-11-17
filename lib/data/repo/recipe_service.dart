import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'entries_repository.dart';
import 'product_service.dart';
import 'recipes_repository.dart';

class RecipeService {
  RecipeService({required this.entries, required this.recipes, required this.productService});
  final EntriesRepository entries;
  final RecipesRepository recipes;
  final ProductService? productService;

  /// Creates a static parent recipe entry and its children for the given recipe id.
  /// - Kind components: create direct child entries with `amount: double` and `showInCalendar=false`.
  /// - Product components: delegate to ProductService to create a product parent+children and link the product parent under the recipe parent.
  Future<String?> createRecipeEntry({
    required String recipeId,
    required DateTime targetAtLocal,
    Map<String, double>? kindOverrides,
    Map<String, int>? productGramOverrides,
    bool showParentInCalendar = true,
    bool isStatic = false,
  }) async {
    final def = await recipes.getRecipe(recipeId);
    if (def == null) return null;
    final comps = await recipes.getComponents(recipeId);

    // Parent payload keeps recipe id and name for simple rendering.
    final parent = await entries.create(
      widgetKind: 'recipe',
      targetAtLocal: targetAtLocal,
      payload: {
        'recipe_id': recipeId,
        'name': def.name,
      },
      showInCalendar: showParentInCalendar,
      schemaVersion: 1,
      recipeId: recipeId,
      isStatic: isStatic,
    );

    // Create children
    for (final c in comps) {
      if (c.type == RecipeComponentType.kind) {
        final amount = (kindOverrides?[c.compId]) ?? (c.amount ?? 0.0);
        await entries.create(
          widgetKind: c.compId,
          targetAtLocal: targetAtLocal,
          payload: {
            'amount': amount,
          },
          showInCalendar: false,
          schemaVersion: 1,
          sourceEntryId: parent.id,
          sourceWidgetKind: 'recipe',
        );
      } else {
        // Product component
        final grams = (productGramOverrides?[c.compId]) ?? (c.grams ?? 0);
        if (productService != null && grams > 0) {
          // Create a product parent entry; then link it under recipe parent by updating source fields.
          final productParentId = await productService!.createProductEntry(
            productId: c.compId,
            productGrams: grams,
            targetAtLocal: targetAtLocal,
            isStatic: true,
          );
          if (productParentId != null) {
            await entries.update(productParentId, {
              'source_entry_id': parent.id,
              'source_widget_kind': 'recipe',
            });
          }
        }
      }
    }

    return parent.id;
  }

  /// Update an existing recipe instance with new values and recompute its children.
  /// - Updates parent entry (targetAt, isStatic, payload)
  /// - Deletes all old children (both kinds and product hierarchies)
  /// - Recreates children from template with new overrides
  Future<void> updateRecipeInstance({
    required String parentEntryId,
    required DateTime targetAtLocal,
    Map<String, double>? kindOverrides,
    Map<String, int>? productGramOverrides,
    bool? isStatic,
  }) async {
    // 1. Load parent and validate it's a recipe instance
    final parent = await entries.getById(parentEntryId);
    if (parent == null || parent.widgetKind != 'recipe') return;
    final recipeId = parent.recipeId;
    if (recipeId == null) return;

    // 2. Load recipe template and components
    final def = await recipes.getRecipe(recipeId);
    if (def == null) return;
    final comps = await recipes.getComponents(recipeId);

    // 3. Update parent row
    final payload = {
      'recipe_id': recipeId,
      'name': def.name,
    };
    await entries.update(parentEntryId, {
      'payload_json': jsonEncode(payload),
      'target_at': targetAtLocal.toUtc().millisecondsSinceEpoch,
      if (isStatic != null) 'is_static': isStatic ? 1 : 0,
    });

    // 4. Delete ALL old children (including product hierarchies)
    final oldChildren = await entries.listChildrenOfParent(parentEntryId);
    for (final child in oldChildren) {
      if (child.widgetKind == 'product' && productService != null) {
        // This is a product parent with its own nutrient children
        await productService!.deleteParentAndChildren(child.id);
      } else {
        // This is a direct kind child
        await entries.delete(child.id);
      }
    }

    // 5. Recreate children from template with new values
    for (final c in comps) {
      if (c.type == RecipeComponentType.kind) {
        final amount = (kindOverrides?[c.compId]) ?? (c.amount ?? 0.0);
        await entries.create(
          widgetKind: c.compId,
          targetAtLocal: targetAtLocal,
          payload: {
            'amount': amount,
          },
          showInCalendar: false,
          schemaVersion: 1,
          sourceEntryId: parentEntryId,
          sourceWidgetKind: 'recipe',
        );
      } else {
        // Product component
        final grams = (productGramOverrides?[c.compId]) ?? (c.grams ?? 0);
        if (productService != null && grams > 0) {
          // Create a product parent entry; then link it under recipe parent
          final productParentId = await productService!.createProductEntry(
            productId: c.compId,
            productGrams: grams,
            targetAtLocal: targetAtLocal,
            isStatic: true,
          );
          if (productParentId != null) {
            await entries.update(productParentId, {
              'source_entry_id': parentEntryId,
              'source_widget_kind': 'recipe',
            });
          }
        }
      }
    }
  }

  /// Delete a recipe template and convert all its instances' children to standalone entries.
  /// - For each recipe parent entry, detach children and delete the parent.
  Future<void> deleteRecipeTemplate(String recipeId) async {
    // Find all parent entries for this recipe
    final parents = await entries.listParentsByRecipeId(recipeId);
    for (final parent in parents) {
      // Detach children and make them visible
      await entries.convertChildrenOfParentToStandalone(parent.id);
      // Delete the parent
      await entries.delete(parent.id);
    }
    // Delete template and its components
    await recipes.deleteRecipe(recipeId);
  }
}

final recipeServiceProvider = Provider<RecipeService?>((ref) {
  final e = ref.watch(entriesRepositoryProvider);
  final r = ref.watch(recipesRepositoryProvider);
  final ps = ref.watch(productServiceProvider);
  if (e == null || r == null) return null;
  return RecipeService(entries: e, recipes: r, productService: ps);
});
